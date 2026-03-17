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
import QuotesPage from './pages/QuotesPage'
import QuoteFormPage from './pages/QuoteFormPage'
import UsersPage from './pages/UsersPage'
import { NotificationProvider } from './context/NotificationContext'
import DashboardLayout from './layout/DashboardLayout'
import { getAuth } from './utils/auth'
import './App.css'

function PrivateRoute({ children }) {
  const [auth, setAuth] = useState(getAuth())
  useEffect(() => {
    setAuth(getAuth())
  }, [])
  // Require both auth object and token so we redirect if only user was saved (old bug)
  if (!auth || !auth.token) return <Navigate to="/" replace />
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
          <Route path="quotes" element={<QuotesPage />} />
          <Route path="quotes/:id" element={<QuoteFormPage />} />
          <Route path="users" element={<UsersPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
