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
import WarehousesPage from './pages/WarehousesPage'
import SuppliersPage from './pages/SuppliersPage'
import UsersPage from './pages/UsersPage'
import Prijemka from './pages/Prijemka'
import PrijemkyListPage from './pages/PrijemkyListPage'
import VydajkyPage from './pages/VydajkyPage'
import RecepturyPage from './pages/RecepturyPage'
import VyrobneProkazaPage from './pages/VyrobneProkazaPage'
import TransportyPage from './pages/TransportyPage'
import SystemStatusPage from './pages/SystemStatusPage'
import { NotificationProvider } from './context/NotificationContext'
import DashboardLayout from './layout/DashboardLayout'
import { getAuth } from './utils/auth'
import './App.css'

// Read auth once from localStorage – no state needed here, auth is stable until logout
function PrivateRoute({ children }) {
  const auth = getAuth()
  if (!auth?.token) return <Navigate to="/" replace />
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
          <Route path="warehouses" element={<WarehousesPage />} />
          <Route path="suppliers" element={<SuppliersPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="prijemky" element={<PrijemkyListPage />} />
          <Route path="prijemky/:id" element={<Prijemka />} />
          <Route path="prijemky/preview" element={<Prijemka />} />
          <Route path="vydajky" element={<VydajkyPage />} />
          <Route path="receptury" element={<RecepturyPage />} />
          <Route path="vyroba-prikazy" element={<VyrobneProkazaPage />} />
          <Route path="transporty" element={<TransportyPage />} />
          <Route path="system-status" element={<SystemStatusPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
