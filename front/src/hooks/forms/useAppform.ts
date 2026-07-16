import { createFormHook } from '@tanstack/react-form'

import AmountInputField from '~/components/form/AmountInput/AmountInputFieldForTanstack'
import ButtonSelectorField from '~/components/form/ButtonSelector/ButtonSelectorFieldForTanstack'
import CheckboxField from '~/components/form/Checkbox/CheckboxFieldForTanstack'
import ComboBoxField from '~/components/form/ComboBox/ComboBoxFieldForTanstack'
import DatePickerField from '~/components/form/DatePicker/DatePickerFieldForTanstack'
import MultipleComboBoxField from '~/components/form/MultipleComboBox/MultipleComboBoxFieldForTanstack'
import RadioField from '~/components/form/Radio/RadioFieldForTanstack'
import RadioGroupField from '~/components/form/Radio/RadioGroupFieldForTanstack'
import SubmitButton from '~/components/form/SubmitButton/SubmitButtonField'
import SwitchField from '~/components/form/Switch/SwitchFieldForTanstack'
import TextInputField from '~/components/form/TextInput/TextInputFieldForTanstack'

import { fieldContext, formContext } from './formContext.ts'

export const { useAppForm, withForm, withFieldGroup } = createFormHook({
  fieldComponents: {
    TextInputField,
    ComboBoxField,
    MultipleComboBoxField,
    SwitchField,
    RadioGroupField,
    CheckboxField,
    RadioField,
    DatePickerField,
    AmountInputField,
    ButtonSelectorField,
  },
  formComponents: {
    SubmitButton,
  },
  fieldContext,
  formContext,
})
