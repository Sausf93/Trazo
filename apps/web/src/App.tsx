import { Navigate, Route, Routes } from "react-router-dom";
import { ProtectedRoute } from "./components/ProtectedRoute";
import { AlertasPage } from "./pages/Alertas";
import { DashboardPage } from "./pages/Dashboard";
import { DispositivosPage } from "./pages/Dispositivos";
import { EjerciciosPage } from "./pages/Ejercicios";
import { EquipoPage } from "./pages/Equipo";
import { LoginPage } from "./pages/Login";
import { PacientesPage } from "./pages/Pacientes";
import { PlanEditorPage } from "./pages/PlanEditor";
import { SesionLivePage } from "./pages/SesionLive";
import { SesionesPage } from "./pages/Sesiones";
import { UsuarioEvolucionPage } from "./pages/UsuarioEvolucion";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />

      <Route
        path="/"
        element={
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/pacientes"
        element={
          <ProtectedRoute>
            <PacientesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/equipo"
        element={
          <ProtectedRoute>
            <EquipoPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/usuarios/:id"
        element={
          <ProtectedRoute>
            <UsuarioEvolucionPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/usuarios/:id/plan"
        element={
          <ProtectedRoute>
            <PlanEditorPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/alertas"
        element={
          <ProtectedRoute>
            <AlertasPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/ejercicios"
        element={
          <ProtectedRoute>
            <EjerciciosPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/sesion"
        element={
          <ProtectedRoute>
            <SesionLivePage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/sesion/:id"
        element={
          <ProtectedRoute>
            <SesionLivePage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/sesiones"
        element={
          <ProtectedRoute>
            <SesionesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/dispositivos"
        element={
          <ProtectedRoute>
            <DispositivosPage />
          </ProtectedRoute>
        }
      />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
