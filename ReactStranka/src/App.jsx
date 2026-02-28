import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import CustomersPage from './pages/CustomersPage'
import CustomerDetailPage from './pages/CustomerDetailPage'
import ScanProductPage from './pages/ScanProductPage'
import './App.css'

function PrivateRoute({ children }) {
  const auth = localStorage.getItem('stockpilot_auth')
  if (!auth) return <Navigate to="/" replace />
  return children
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LoginPage />} />
        <Route
          path="/dashboard"
          element={
            <PrivateRoute>
              <DashboardPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard/customers"
          element={
            <PrivateRoute>
              <CustomersPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard/customers/:id"
          element={
            <PrivateRoute>
              <CustomerDetailPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard/scan"
          element={
            <PrivateRoute>
              <ScanProductPage />
            </PrivateRoute>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
