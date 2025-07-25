/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./src/**/*.{ts,tsx}",
    "./index.html",
  ],
  theme: {
    extend: {},
  },
  corePlugins: {
    preflight: false,
  },
  important: true,
}
