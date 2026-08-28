interface ButtonProps {
  text: string
  loading?: boolean
  disabled?: boolean
  onClick: () => void
}

function Button({ text, loading = false, disabled = false, onClick }: ButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled || loading}
      className="mt-1 h-11 w-full rounded-lg bg-yellow-400 text-sm font-semibold text-gray-900 transition hover:bg-yellow-500 disabled:cursor-not-allowed disabled:opacity-60"
    >
      {loading ? 'Logging in...' : text}
    </button>
  )
}

export default Button
