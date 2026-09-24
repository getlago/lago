// matching_filter_v2: same decision as matching_filter (models.MatchingFilter,
// events-processor models/flat_filters.go:180), built for large filter sets.
//
// v1 takes the charge's candidate array as JSONB, so EVERY (event, charge)
// row pays a JSONB -> text render, a copy into WASM memory, a full serde_json
// parse of every candidate, and the same again for the returned object. That
// is linear in the size of the charge's filter set per event, and some
// charges carry thousands of filters. v2 changes three things:
//
//   1. It takes the array as TEXT (flat_filters_agg_v2.filters_text, rendered
//      once per CDC change, not per event) and compiles it into an inverted
//      index kept in a per-instance cache. A cache hit costs a hash plus a
//      string compare, no parse. The cache is keyed by the FULL text
//      (compared on hit), so a changed filter set, including an
//      __ALL_FILTER_VALUES__ expansion that bumps no updated_at, can never
//      read a stale matcher.
//   2. It returns the winning POSITION in the array (0-based), or -1 for the
//      charge's default bucket, instead of a JSONB object. The caller reads
//      the winner's fields natively with filters_agg -> idx.
//   3. Matching walks the charge's distinct filter keys (a handful) instead
//      of every candidate: each key/value hit bumps the candidates allowing
//      it, and a candidate matches when all of its keys were hit.
//
// Selection semantics are unchanged from v1 (parity is tested in lib.rs):
// every filter key must be present and non-null on the event with its JSON
// text in the allowed list; a candidate without filters or with a null value
// list never matches; among matches the most keys wins and the FIRST of
// equally-specific ones is kept; no match returns the default bucket.
// Returns NULL for an unparseable, non-array or empty input (the caller never
// produces those: every charge has at least one flat_filters row).
fn matching_filter_v2(filters_text: &str, properties: serde_json::Value) -> Option<i32> {
    MF_V2_CACHE.with(|cache| {
        let mut cache = cache.borrow_mut();
        if let Some(matcher) = cache.get(filters_text) {
            return Some(matcher.pick(&properties));
        }
        let matcher = MfV2Matcher::compile(filters_text)?;
        let res = matcher.pick(&properties);
        cache.insert(filters_text, matcher);
        Some(res)
    })
}

// Bounds of the per-instance cache: dropped wholesale past either limit. The
// working set is the catalog's charges, so a flush is rare and only costs one
// recompile per charge.
const MF_V2_CACHE_MAX_BYTES: usize = 64 * 1024 * 1024;
const MF_V2_CACHE_MAX_ENTRIES: usize = 50_000;

thread_local! {
    static MF_V2_CACHE: std::cell::RefCell<MfV2Cache> = std::cell::RefCell::new(MfV2Cache::default());
}

#[derive(Default)]
struct MfV2Cache {
    map: std::collections::HashMap<String, MfV2Matcher, MfV2BuildHasher>,
    bytes: usize,
}

impl MfV2Cache {
    fn get(&self, filters_text: &str) -> Option<&MfV2Matcher> {
        self.map.get(filters_text)
    }

    fn insert(&mut self, filters_text: &str, matcher: MfV2Matcher) {
        if self.bytes + filters_text.len() > MF_V2_CACHE_MAX_BYTES
            || self.map.len() >= MF_V2_CACHE_MAX_ENTRIES
        {
            self.map.clear();
            self.bytes = 0;
        }
        self.bytes += filters_text.len();
        self.map.insert(filters_text.to_string(), matcher);
    }
}

// The cache key is the whole filter-set text (up to hundreds of KB), hashed on
// every call. std's default SipHash is DoS-resistant but slow on long inputs;
// the keys come from our own catalog, so a word-at-a-time multiplicative hash
// (FxHash-style) is enough. A collision only costs a string compare.
#[derive(Default, Clone, Copy)]
struct MfV2BuildHasher;

impl std::hash::BuildHasher for MfV2BuildHasher {
    type Hasher = MfV2Hasher;
    fn build_hasher(&self) -> MfV2Hasher {
        MfV2Hasher(0)
    }
}

struct MfV2Hasher(u64);

impl MfV2Hasher {
    fn add(&mut self, word: u64) {
        self.0 = (self.0.rotate_left(5) ^ word).wrapping_mul(0x517c_c1b7_2722_0a95);
    }
}

impl std::hash::Hasher for MfV2Hasher {
    fn write(&mut self, bytes: &[u8]) {
        // The length disambiguates the zero-padded last word ("a" vs "a\0").
        self.add(bytes.len() as u64);
        let mut chunks = bytes.chunks_exact(8);
        for chunk in &mut chunks {
            let mut word = [0u8; 8];
            word.copy_from_slice(chunk);
            self.add(u64::from_le_bytes(word));
        }
        let rest = chunks.remainder();
        if !rest.is_empty() {
            let mut word = [0u8; 8];
            word[..rest.len()].copy_from_slice(rest);
            self.add(u64::from_le_bytes(word));
        }
    }

    fn write_u8(&mut self, i: u8) {
        self.add(i as u64);
    }

    fn write_usize(&mut self, i: usize) {
        self.add(i as u64);
    }

    fn finish(&self) -> u64 {
        self.0
    }
}

struct MfV2Matcher {
    // Per candidate: how many filter keys it has, 0 when it has no filters
    // (null or empty map) and therefore never matches.
    key_counts: Vec<u32>,
    // filter key -> allowed value -> candidates allowing it, ascending and
    // without duplicates. A candidate whose value list for a key is null (or
    // holds no string) is counted in key_counts but listed under no value, so
    // it can never reach its key count: v1's "null never matches".
    index: std::collections::HashMap<String, std::collections::HashMap<String, Vec<u32>>>,
}

impl MfV2Matcher {
    fn compile(filters_text: &str) -> Option<MfV2Matcher> {
        let parsed: serde_json::Value = serde_json::from_str(filters_text).ok()?;
        let arr = match parsed.as_array() {
            Some(a) if !a.is_empty() => a,
            _ => return None,
        };

        let mut key_counts = Vec::with_capacity(arr.len());
        let mut index: std::collections::HashMap<String, std::collections::HashMap<String, Vec<u32>>> =
            std::collections::HashMap::new();

        for (pos, candidate) in arr.iter().enumerate() {
            let pos = pos as u32;
            let values = match candidate.get("filters").and_then(|v| v.as_object()) {
                Some(m) if !m.is_empty() => m,
                _ => {
                    key_counts.push(0);
                    continue;
                }
            };
            key_counts.push(values.len() as u32);

            for (key, allowed) in values {
                let by_value = index.entry(key.clone()).or_default();
                let allowed = match allowed.as_array() {
                    Some(a) => a,
                    None => continue,
                };
                for value in allowed {
                    // v1 compares with x.as_str(): non-string entries never match.
                    if let Some(value) = value.as_str() {
                        let positions = by_value.entry(value.to_string()).or_default();
                        // Candidates are visited in order, so a value repeated in
                        // one list can only repeat the last position.
                        if positions.last() != Some(&pos) {
                            positions.push(pos);
                        }
                    }
                }
            }
        }

        Some(MfV2Matcher { key_counts, index })
    }

    fn pick(&self, properties: &serde_json::Value) -> i32 {
        let mut hits: Vec<u32> = Vec::new();
        for (key, by_value) in &self.index {
            let prop = match properties.get(key.as_str()) {
                None | Some(serde_json::Value::Null) => continue,
                Some(v) => v,
            };
            let positions = match prop {
                // Same rule as json_value_text, without allocating for strings.
                serde_json::Value::String(s) => by_value.get(s.as_str()),
                other => by_value.get(json_value_text(other).as_str()),
            };
            if let Some(positions) = positions {
                hits.extend_from_slice(positions);
            }
        }
        if hits.is_empty() {
            return -1;
        }

        // A candidate matches when it was hit once per key it has. Scanning
        // positions in ascending order with a strictly-greater replacement
        // keeps the first of equally-specific matches, like v1 and Go.
        hits.sort_unstable();
        let mut best: Option<(u32, u32)> = None;
        let mut i = 0;
        while i < hits.len() {
            let pos = hits[i];
            let mut j = i;
            while j < hits.len() && hits[j] == pos {
                j += 1;
            }
            let key_count = self.key_counts[pos as usize];
            if key_count > 0 && (j - i) as u32 == key_count {
                match best {
                    Some((_, best_count)) if key_count <= best_count => {}
                    _ => best = Some((pos, key_count)),
                }
            }
            i = j;
        }
        best.map(|(pos, _)| pos as i32).unwrap_or(-1)
    }
}
