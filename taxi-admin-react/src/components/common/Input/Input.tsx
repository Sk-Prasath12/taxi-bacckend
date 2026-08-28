import type { ChangeEvent } from 'react'

interface InputProps {
  label: string
  type?: 'text' | 'email' | 'password'
  value: string
  onChange: (value: string) => void
  error?: string
  placeholder?: string
}

function Input({
  label,
  type = 'text',
  value,
  onChange,
  error,
  placeholder,
}: InputProps) {
  const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
    onChange(event.target.value)
  }

  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-sm font-semibold text-gray-900">{label}</label>
      <input
        type={type}
        value={value}
        onChange={handleChange}
        placeholder={placeholder}
        className={`h-11 w-full rounded-lg border bg-white px-3 text-sm text-gray-900 transition focus:outline-none focus:ring-2 ${
          error
            ? 'border-red-400 focus:ring-red-200'
            : 'border-gray-200 focus:border-yellow-400 focus:ring-yellow-200'
        }`}
      />
      {error ? <p className="text-xs text-red-500">{error}</p> : null}
    </div>
  )
}

export default Input
