# Contributing to Lago

If you're reading this, we would first like to thank you for taking the time to contribute.

The following is a set of guidelines for contributing to Lago and its packages, which are hosted in the [Lago Organization](https://github.com/getlago) on GitHub. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

#### Table Of Contents

[Code of Conduct](#code-of-conduct)

[I don't want to read this whole thing, I just have a question!!!](#i-dont-want-to-read-this-whole-thing-i-just-have-a-question)

[What should I know before I get started?](#what-should-i-know-before-i-get-started)

- [Lago and Packages](#lago-and-packages)
- [Design Decisions](#design-decisions)

[How Can I Contribute?](#how-can-i-contribute)

- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Your First Code Contribution](#your-first-code-contribution)
- [Pull Requests](#pull-requests)

[Styleguides](#styleguides)

- [Git Commit Messages](#git-commit-messages)
- [General style guide](#general-style-guide)

[Additional Notes](#additional-notes)

- [Issue and Pull Request Labels](#issue-and-pull-request-labels)

## Code of Conduct

This project and everyone participating in it is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [dev@getlago.com](mailto:dev@getlago.com).

## I don't want to read this whole thing I just have a question!!!

- [Github Discussions, the official Lago](https://github.com/getlago/lago-front/discussions)
- [Lago Discourse](https://community.getlago.com/)
- [Lago FAQ](https://github.com/getlago/lago-front/discussions)
- [Lago official documentation](https://docs.getlago.com/)
- [Lago feature request](https://community.getlago.com/c/feature-requests/11)

## What should I know before I get started?

### Lago and Packages

Lago is an open source project. When you initially consider contributing to Lago, you might be unsure about which of Lago elements implements the functionality you want to change or report a bug for. This section should help you with that.

Here's a list of Lago's elements:

- [lago/core](https://github.com/getlago/lago) - Lago Core!
- [lago/front](https://github.com/getlago/lago-front) - Lago's UI (you are here 📍)
- [lago/api](https://github.com/getlago/lago-api) - Lago's API.

#### The different clients

- [lago/client/nodejs](https://github.com/getlago/lago-nodejs-client) - Lago's Nodejs Client
- [lago/client/python](https://github.com/getlago/lago-python-client) - Lago's Python Client
- [lago/client/ruby](https://github.com/getlago/lago-ruby-client) - Lago's Ruby Client

Also, because Lago is extensible, it's possible that a feature you've become accustomed to in Lago or an issue you're encountering isn't coming from a bundled package at all, but rather a community package you've installed. Each community package has its own repository too.

### Design Decisions

If you have a question around how we do things, check to see if it is documented in the wiki of the related repository. If it is _not_ documented there, please open a new topic on [Github Discussions](https://github.com/getlago/lago-front/discussions) and ask your question.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for Lago. Following these guidelines helps maintainers and the community understand your report :pencil:, reproduce the behavior :computer: :computer:, and find related reports :mag_right:.

Before creating bug reports, please check [this list](#before-submitting-a-bug-report) as you might find out that you don't need to create one. When you are creating a bug report, please [include as many details as possible](#how-do-i-submit-a-good-bug-report). Fill out the required [template](https://github.com/getlago/lago-front/issues/new?assignees=&labels=%F0%9F%90%9E+bug&template=bug.md&title=%5BBUG%5D%3A+), the information it asks for helps us resolve issues faster.

> **Note:** If you find a **Closed** issue that seems like it is the same thing that you're experiencing, open a new issue and include a link to the original issue in the body of your new one.

#### Before Submitting A Bug Report

- **Check the [discussions](https://github.com/getlago/lago-front/discussions)** for a list of common questions and problems.
- **Determine [which element the problem should be reported in](#lago-and-packages)**.
- **Perform a [cursory search](https://github.com/search?q=+is%3Aissue+user%3Agetlago)** to see if the problem has already been reported. If it has **and the issue is still open**, add a comment to the existing issue instead of opening a new one.

#### How Do I Submit A (Good) Bug Report?

Bugs are tracked as [GitHub issues](https://guides.github.com/features/issues/). After you've determined [which element](#lago-and-packages) your bug is related to, create an issue and provide the following information by filling in the template.

Explain the problem and include additional details to help maintainers reproduce the problem:

- **Use a clear and descriptive title** for the issue to identify the problem.
- **Describe the exact steps which reproduce the problem** in as many details as possible. For example, start by explaining how you started Lago, e.g. which command exactly you used in the terminal, or how you started Lago otherwise. When listing steps, **don't just say what you did, but explain how you did it**.
- **Provide specific examples to demonstrate the steps**. Include links to files or GitHub projects, or copy/pasteable snippets, which you use in those examples. If you're providing snippets in the issue, use [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).
- **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
- **Explain which behavior you expected to see instead and why.**
- **Include screenshots and animated GIFs** which show you following the described steps and clearly demonstrate the problem. If you use the keyboard while following the steps. You can use [this tool](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux.
- **If you're reporting that Lago crashed**, include a crash report with a stack trace from the operating system. Include the crash report in the issue in a [code block](https://help.github.com/articles/markdown-basics/#multiple-lines), a [file attachment](https://help.github.com/articles/file-attachments-on-issues-and-pull-requests/), or put it in a [gist](https://gist.github.com/) and provide link to that gist.
- **If the problem wasn't triggered by a specific action**, describe what you were doing before the problem happened and share more information using the guidelines below.

Provide more context by answering these questions:

- **Did the problem start happening recently** (e.g. after updating to a new version of Lago) or was this always a problem?
- If the problem started happening recently, **can you reproduce the problem in an older version of Lago?** What's the most recent version in which the problem doesn't happen? You can download older versions of Lago from [the releases page](https://github.com/getlago/lago/releases).
- **Can you reliably reproduce the issue?** If not, provide details about how often the problem happens and under which conditions it normally happens.

Include details about your configuration and environment:

- **Which version of Lago are you using?**
- **What's the name and version of the OS you're using**?
- **Are you running Lago in a virtual machine?** If so, which VM software are you using and which operating systems and versions are used for the host and the guest?
- **Which [packages](#lago-and-packages) do you have installed?**.

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Lago, including completely new features and minor improvements to existing functionality. Following these guidelines helps maintainers and the community understand your suggestion :pencil: and find related suggestions :mag_right:.

Before creating enhancement suggestions, please check [this list](#before-submitting-an-enhancement-suggestion) as you might find out that you don't need to create one. When you are creating an enhancement suggestion, please [include as many details as possible](#how-do-i-submit-a-good-enhancement-suggestion). Fill in the [template](https://github.com/getlago/lago-front/issues/new?assignees=&labels=%F0%9F%9B%A0+feature&template=feature.md&title=%5BFEAT%5D%3A+), including the steps that you imagine you would take if the feature you're requesting existed.

#### Before Submitting An Enhancement Suggestion

- **Check the [documentation](https://docs.getlago.com)** you might discover that the enhancement is already available. Most importantly, check if you're using [the latest version of Lago](https://github.com/getlago/lago/releases).
- **Determine [which element the enhancement should be suggested in](#lago-and-packages).**
- **Perform a [cursory search](https://github.com/search?q=+is%3Aissue+user%3Agetlago)** to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.

#### How Do I Submit A (Good) Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub issues](https://guides.github.com/features/issues/). After you've determined [which repository](#lago-and-packages) your enhancement suggestion is related to, create an issue and provide the following information:

- **Use a clear and descriptive title** for the issue to identify the suggestion.
- **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
- **Provide specific examples to demonstrate the steps**. Include copy/pasteable snippets which you use in those examples, as [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
- **Include screenshots and animated GIFs** which help you demonstrate the steps or point out the part of Lago which the suggestion is related to. You can use [this tool](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux.
- **Explain why this enhancement would be useful** to most Lago users and isn't something that can or should be implemented as a [community package](#lago-and-packages).
- **Specify which version of Lago you're using.**
- **Specify the name and version of the OS you're using.**

### Your First Code Contribution

Unsure where to begin contributing to Lago? You can start by looking through these `beginner` and `help-wanted` labels:

- Beginner issues - issues which should only require a few lines of code, and a test or two.
- Help wanted issues - issues which should be a bit more involved than `beginner` issues.

Both issue lists are sorted by total number of comments. While not perfect, number of comments is a reasonable proxy for impact a given change will have.

#### Local development

Lago Core and all packages can be developed locally. For instructions on how to do this, see the following sections in the [Lago documentation](https://github.com/getlago/lago-front/wiki):

### Pull Requests

The process described here has several goals:

- Maintain Lago's quality
- Fix problems that are important to users
- Engage the community in working toward the best possible Lago
- Enable a sustainable system for Lago's maintainers to review contributions

Please follow these steps to have your contribution considered by the maintainers:

1. Follow all instructions in [the template](https://github.com/getlago/lago/blob/main/PULL_REQUEST_TEMPLATE.md)
2. Follow the [styleguides](#styleguides)
3. After you submit your pull request, verify that all [status checks](https://help.github.com/articles/about-status-checks/) are passing <details><summary>What if the status checks are failing?</summary>If a status check is failing, and you believe that the failure is unrelated to your change, please leave a comment on the pull request explaining why you believe the failure is unrelated. A maintainer will re-run the status check for you. If we conclude that the failure was a false positive, then we will open an issue to track that problem with our status check suite.</details>

While the prerequisites above must be satisfied prior to having your pull request reviewed, the reviewer(s) may ask you to complete additional design work, tests, or other changes before your pull request can be ultimately accepted.

## Styleguides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line
- When only changing documentation, include `[ci skip]` in the commit title
- Use the [Convention commits](https://www.conventionalcommits.org/en/v1.0.0/) convention.

### General Style Guide

The code is linted and prettified with [Prettier](https://prettier.io/).
Make sure to check the [code guidelines in the wiki](https://github.com/getlago/lago-front/wiki/CodeGuideline).

## Additional Notes

### Issue and Pull Request Labels

This section lists the labels we use to help us track and manage issues and pull requests.

[GitHub search](https://help.github.com/articles/searching-issues/) makes it easy to use labels for finding groups of issues or pull requests you're interested in. To help you find issues and pull requests, each label is listed with search links for finding open items with that label. We encourage you to read about [other search filters](https://help.github.com/articles/searching-issues/) which will help you write more focused queries.

The labels are loosely grouped by their purpose, but it's not required that every issue has a label from every group or that an issue can't have more than one label from the same group.

Please open an issue if you have suggestions for new labels.

#### Type of Issue and Issue State

| Label name      | :mag_right:                                                                          | Description                                                                                                                          |
| --------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `feature`       | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%9B%A0%20feature)        | Feature requests.                                                                                                                    |
| `improvement`   | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%8C%88%20improvement)    | Improvement requests (of existing features).                                                                                         |
| `documentation` | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%93%84%20Documentation)  | Feature requests.                                                                                                                    |
| `bug`           | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%90%9E%20bug)            | Confirmed bugs or reports that are very likely to be bugs.                                                                           |
| `critical bug`  | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%99%80%20Critical%20bug) | Confirmed critical bugs or reports that are very likely to be bugs.                                                                  |
| `chore`         | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%A5%B7%20chore)          | Chore related issues                                                                                                                 |
| `ui`            | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%8E%A8%20UI)             | UI / design related issues.                                                                                                          |
| `help-wanted`   | [Issues](https://github.com/getlago/lago/labels/help-wanted)                         | The Lago core team would appreciate help from the community in resolving these issues.                                               |
| `beginner`      | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%90%A3%20Beginner)       | Less complex issues which would be good first issues to work on for users who want to contribute to Lago.                            |
| `wontfix`       | [Issues](https://github.com/getlago/lago-front/labels/%E2%9D%8C%20wontfix)           | The Lago core team has decided not to fix these issues for now, either because they're working as intended or for some other reason. |
| `dependencies`  | [Issues](https://github.com/getlago/lago-front/labels/%F0%9F%94%97%20dependencies)   | Issues reported on the wrong repository                                                                                              |

#### Pull Request Labels

| Label name         | :mag_right:                                                                                      | Description                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `needs-review`     | [PR](https://github.com/getlago/lago-front/pulls?q=is%3Apr+is%3Aopen+review%3Arequired)          | Pull requests which need code review, and approval from maintainers or Lago core team.   |
| `requires-changes` | [PR](https://github.com/getlago/lago-front/pulls?q=is%3Apr+is%3Aopen+review%3Achanges-requested) | Pull requests which need to be updated based on review comments and then reviewed again. |
| `review-approved`  | [PR](https://github.com/getlago/lago-front/pulls?q=is%3Apr+is%3Aopen+review%3Aapproved)          | That has been approved                                                                   |
