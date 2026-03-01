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
          path="/dashboard/products"
          element={
            <PrivateRoute>
              <ProductsPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard/products/:uniqueId"
          element={
            <PrivateRoute>
              <ProductDetailPage />
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
        <Route
          path="/dashboard/production"
          element={
            <PrivateRoute>
              <ProductionPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard/production/new"
          element={
            <PrivateRoute>
              <ProductionBatchFormPage />
            </PrivateRoute>
          }
        />
        <Route
          path="/dashboard/production/:id"
          element={
            <PrivateRoute>
              <ProductionBatchDetailPage />
            </PrivateRoute>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
