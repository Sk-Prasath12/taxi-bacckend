/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        taxi: {
          yellow: '#FFC107',
          'yellow-hover': '#E0A800',
          'icon-bg': '#FFE082',
          bg: '#F8FAFC',
        },
      },
    },
  },
  plugins: [],
}

