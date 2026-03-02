import { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import CustomersPage from './pages/CustomersPage'
import CustomerDetailPage from './pages/CustomerDetailPage'
import ProductsPage from './pages/ProductsPage'
import ProductDetailPage from './pages/ProductDetailPage'
import ScanProductPage from './pages/ScanProductPage'
import ProductionPage from './pages/ProductionPage'
import ProductionBatchFormPage from './pages/ProductionBatchFormPage'
import ProductionBatchDetailPage from './pages/ProductionBatchDetailPage'
import { NotificationProvider } from './context/NotificationContext'
import DashboardLayout from './layout/DashboardLayout'
import './App.css'

function getAuth() {
  try {
    const raw = localStorage.getItem('stockpilot_auth')
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

function PrivateRoute({ children }) {
  const [auth, setAuth] = useState(getAuth())
  useEffect(() => {
    const a = getAuth()
    setAuth(a)
  }, [])
  if (!auth) return <Navigate to="/" replace />
  return <NotificationProvider auth={auth}>{children}</NotificationProvider>
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LoginPage />} />
        <Route path="/dashboard" element={<PrivateRoute><DashboardLayout /></PrivateRoute>}>
          <Route index element={<DashboardPage />} />
          <Route path="customers" element={<CustomersPage />} />
          <Route path="customers/:id" element={<CustomerDetailPage />} />
          <Route path="products" element={<ProductsPage />} />
          <Route path="products/:uniqueId" element={<ProductDetailPage />} />
          <Route path="scan" element={<ScanProductPage />} />
          <Route path="production" element={<ProductionPage />} />
          <Route path="production/new" element={<ProductionBatchFormPage />} />
          <Route path="production/:id" element={<ProductionBatchDetailPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
