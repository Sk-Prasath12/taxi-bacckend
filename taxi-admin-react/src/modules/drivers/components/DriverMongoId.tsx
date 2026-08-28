import { useState } from 'react'

interface DriverMongoIdProps {
  id: string
  compact?: boolean
}

function DriverMongoId({ id, compact = false }: DriverMongoIdProps) {
  const [copied, setCopied] = useState(false)

  if (!id) {
    return <span className="text-gray-400">—</span>
  }

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(id)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      setCopied(false)
    }
  }

  return (
    <span className="inline-flex flex-wrap items-center gap-2 font-mono text-xs text-gray-700">
      <span title={id}>{compact ? `${id.slice(0, 10)}…` : id}</span>
      <button
        type="button"
        onClick={() => void copy()}
        className="rounded border border-gray-300 bg-white px-2 py-0.5 text-[11px] font-semibold text-gray-800 hover:bg-gray-50"
      >
        {copied ? 'Copied' : 'Copy driver ID'}
      </button>
    </span>
  )
}

export default DriverMongoId
