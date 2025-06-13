import { Providers } from './app/providers'
import { AppRouter } from './app/router'
import './App.css'

function App() {
  return (
    <Providers>
      <AppRouter />
    </Providers>
  )
}

export default App
