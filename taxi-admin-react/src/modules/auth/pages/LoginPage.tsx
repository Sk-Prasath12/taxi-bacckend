import LoginForm from '../components/LoginForm'

function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-taxi-bg px-4 py-6">
      <section className="w-full max-w-md rounded-xl border border-gray-200 bg-white p-7 shadow-sm">
        <p className="mb-2 text-xs font-bold uppercase tracking-widest text-amber-700">Taxi Admin</p>
        <h1 className="text-3xl font-bold text-gray-900">Admin Login</h1>
        <p className="mt-1 text-sm text-gray-500">Taxi Admin Panel</p>
        <LoginForm />
      </section>
    </main>
  )
}

export default LoginPage
