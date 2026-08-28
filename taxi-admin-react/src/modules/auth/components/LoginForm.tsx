import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Button from '../../../components/common/Button/Button'
import Input from '../../../components/common/Input/Input'
import { getApiConfigHint, isProductionMisconfiguredApi } from '../../../config/api.config'
import { ROUTES } from '../../../utils/constants'
import { loginAdmin, saveAdminSession } from '../services/auth.service'

interface FormErrors {
  email?: string
  password?: string
  general?: string
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function LoginForm() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [errors, setErrors] = useState<FormErrors>({})
  const [isSubmitting, setIsSubmitting] = useState(false)

  const validateForm = (): boolean => {
    const nextErrors: FormErrors = {}

    if (!email.trim()) {
      nextErrors.email = 'Email is required.'
    } else if (!EMAIL_PATTERN.test(email.trim())) {
      nextErrors.email = 'Please enter a valid email address.'
    }

    if (!password.trim()) {
      nextErrors.password = 'Password is required.'
    }

    setErrors(nextErrors)
    return Object.keys(nextErrors).length === 0
  }

  const handleSubmit = async () => {
    if (!validateForm()) {
      return
    }

    try {
      setIsSubmitting(true)
      setErrors({})
      const response = await loginAdmin(email.trim(), password)
      saveAdminSession(response.token)
      navigate(ROUTES.ADMIN_DASHBOARD, { replace: true })
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unable to login. Please try again.'

      setErrors({ general: message })
    } finally {
      setIsSubmitting(false)
    }
  }

  const isLoginDisabled = !email.trim() || !password.trim()

  return (
    <div className="mt-6 flex flex-col gap-3.5">
      <Input
        label="Email"
        type="email"
        value={email}
        onChange={setEmail}
        error={errors.email}
        placeholder="admin@taxigo.com"
      />

      <Input
        label="Password"
        type="password"
        value={password}
        onChange={setPassword}
        error={errors.password}
        placeholder="Enter password"
      />

      {errors.general ? (
        <p className="text-xs text-red-500">{errors.general}</p>
      ) : null}

      <p className={`text-xs ${isProductionMisconfiguredApi() ? 'text-amber-700' : 'text-gray-400'}`}>
        {getApiConfigHint()}
      </p>
      <p className="text-xs text-gray-400">Login: admin@taxigo.com / admin123</p>

      <Button
        text="Login"
        loading={isSubmitting}
        disabled={isLoginDisabled}
        onClick={handleSubmit}
      />
    </div>
  )
}

export default LoginForm
