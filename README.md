# CreditSystem - Fintech Multi-Country Credit Application MVP

Sistema MVP para gestionar solicitudes de credito en multiples paises (Mexico y Colombia), construido con Elixir, Phoenix Framework y LiveView.

## Quick Start (< 5 minutos)

### Prerequisitos
- Elixir >= 1.15 (probado con 1.19.5)
- Erlang/OTP >= 26 (probado con OTP 28)
- PostgreSQL >= 14 (probado con 18)
- Node.js >= 18 (probado con 24.13.1)

### Instalacion y ejecucion

```bash
# Clonar el repositorio
git clone <repo_url>
cd credit_system

# Setup completo (deps + DB + migrations + seeds)
make setup

# Iniciar el servidor
make run
```

Visita [http://localhost:4000](http://localhost:4000) para ver la aplicacion.

### Usuarios de prueba (creados por seeds)
| Email | Password | Rol |
|-------|----------|-----|
| admin@creditsystem.com | admin123 | admin |
| analyst@creditsystem.com | analyst123 | analyst |

### Comandos utiles
```bash
make setup    # Instalar deps + crear DB + migrar + seed
make run      # Iniciar servidor Phoenix
make iex      # Iniciar con IEx interactivo
make test     # Correr tests
make migrate  # Correr migraciones
make seed     # Poblar datos de prueba
make reset    # Resetear DB completa
make format   # Formatear codigo
make lint     # Compilar con warnings-as-errors
```

## Arquitectura

### Stack Tecnologico
| Componente | Tecnologia | Razon |
|-----------|-----------|-------|
| Backend | Elixir + Phoenix 1.8 | Concurrencia nativa via BEAM, fault-tolerance, hot-reload |
| Frontend | Phoenix LiveView | Real-time nativo via WebSocket, sin framework JS separado |
| Database | PostgreSQL 18 | JSONB, triggers, pg_notify, particionamiento nativo |
| Job Queue | Oban | Cola basada en PostgreSQL, no requiere Redis/RabbitMQ |
| Auth | Guardian + JWT | Estandar industria, stateless, escalable |
| Cache | Cachex | Cache in-process con TTL, ETS-backed |
| HTTP Client | Finch | Connection pooling eficiente para webhooks |

### Estructura del proyecto
```
lib/
  credit_system/
    applications/          # Contexto de solicitudes de credito
      credit_application.ex  # Schema principal
      state_machine.ex       # Maquina de estados
      audit_log.ex          # Schema de auditoria
    countries/             # Logica especifica por pais
      country.ex            # Behaviour (interfaz)
      mexico.ex             # Reglas MX: CURP, limites
      colombia.ex           # Reglas CO: CC, ratio deuda/ingreso
    banking/               # Integracion bancaria
      provider.ex           # Behaviour (interfaz)
      mexico_provider.ex    # Mock proveedor MX
      colombia_provider.ex  # Mock proveedor CO
    workers/               # Procesamiento asincrono (Oban)
      risk_evaluation_worker.ex   # Evaluacion de riesgo
      audit_worker.ex             # Registro de auditoria
      webhook_worker.ex           # Envio de webhooks
      notification_worker.ex      # Notificaciones
    webhooks/              # Manejo de webhooks
      handler.ex            # Procesador de webhooks entrantes
    auth/                  # Autenticacion JWT
      guardian.ex, pipeline.ex, user.ex, error_handler.ex
    cache.ex               # Wrapper de Cachex
    applications.ex        # Contexto principal (API publica)
  credit_system_web/
    controllers/           # REST API
    live/                  # LiveView frontend
      application_live/    # CRUD + real-time
```

## Modelo de Datos

### Tabla: `credit_applications`
| Campo | Tipo | Descripcion |
|-------|------|-------------|
| id | UUID | Primary key |
| country | string | Codigo de pais (MX, CO) |
| full_name | string | Nombre completo del solicitante |
| identity_document | string | Documento de identidad (CURP/CC) |
| document_type | string | Tipo de documento |
| requested_amount | decimal(18,2) | Monto solicitado |
| monthly_income | decimal(18,2) | Ingreso mensual |
| application_date | date | Fecha de solicitud |
| status | string | Estado actual |
| banking_info | jsonb | Info bancaria del proveedor |
| risk_score | integer | Score de riesgo (0-100) |
| metadata | jsonb | Metadata adicional |
| lock_version | integer | Optimistic locking |
| user_id | UUID FK | Usuario que creo la solicitud |

### Tabla: `audit_logs`
Registra todos los cambios de estado y acciones sobre solicitudes.

### Tabla: `webhook_events`
Registra webhooks entrantes y salientes con intentos y respuestas.

### Tabla: `users`
Usuarios con autenticacion JWT y roles (admin/analyst).

## Decisiones Tecnicas

### 1. Country Behaviour Pattern
Se usa el patron Behaviour de Elixir para definir una interfaz comun que cada pais implementa:
- `validate_document/1` - Validacion de documento de identidad
- `validate_application/1` - Reglas de negocio del pais
- `document_type/0`, `country_code/0`, `max_amount/0`

Agregar un nuevo pais requiere solo crear un modulo que implemente el behaviour y registrarlo en `Country.get_module/1`.

### 2. Banking Provider Pattern
Mismo patron Behaviour para proveedores bancarios. Cada pais tiene su proveedor mock que simula latencia real y retorna datos especificos del pais.

### 3. State Machine
Flujo de estados definido como mapa de transiciones validas:
```
pending -> validating -> under_review -> approved -> disbursed
                      -> approved     -> rejected
                      -> rejected
```
Las transiciones son validadas antes de ejecutarse y disparan workers asincronos.

### 4. Oban sobre Redis/RabbitMQ
Oban usa la misma base de datos PostgreSQL como cola de trabajos. Ventajas:
- No requiere infraestructura adicional
- Transaccionalidad con la DB
- Reintentos automaticos
- Dashboard integrado
- Colas separadas con concurrencia configurable

### 5. LiveView sobre React/Vue
LiveView proporciona real-time nativo sin JavaScript adicional. Los cambios de estado se propagan automaticamente via PubSub a todas las conexiones activas.

## Reglas de Negocio por Pais

### Mexico (MX)
- **Documento**: CURP (18 caracteres, formato regex validado)
- **Regla 1**: Ingreso mensual >= 3x el pago mensual (monto/12)
- **Regla 2**: Monto maximo $500,000 MXN
- **Regla 3**: Montos > $250,000 requieren revision adicional

### Colombia (CO)
- **Documento**: Cedula de Ciudadania (6-10 digitos)
- **Regla 1**: Ratio deuda total / ingreso mensual < 0.4
- **Regla 2**: Monto maximo $200,000,000 COP
- **Regla 3**: Montos > $100,000,000 requieren revision adicional

## Procesamiento Asincrono y Colas

### Tecnologia: Oban (PostgreSQL-backed)
Colas configuradas:
| Cola | Concurrencia | Proposito |
|------|-------------|-----------|
| risk | 5 | Evaluacion de riesgo |
| webhooks | 10 | Envio de webhooks salientes |
| audit | 3 | Registro de auditoria |
| notifications | 5 | Notificaciones |

### Flujo asincrono
1. Se crea una solicitud (API o LiveView)
2. Se encolan jobs:
   - `RiskEvaluationWorker`: consulta proveedor bancario, evalua reglas, calcula risk_score
   - `AuditWorker`: registra la creacion en audit_logs
   - `NotificationWorker`: procesa notificacion de creacion
3. Al completar la evaluacion de riesgo, se encolan mas jobs:
   - `WebhookWorker`: notifica a endpoints externos
   - `AuditWorker`: registra el resultado

### PostgreSQL Triggers
- `application_status_change_trigger`: Emite `pg_notify` en cada cambio de estado
- `application_created_trigger`: Emite `pg_notify` en cada nueva solicitud

Estos triggers generan eventos que pueden ser consumidos por listeners de PostgreSQL para procesamiento adicional.

## Webhooks

### Webhook Entrante
- **Endpoint**: `POST /api/webhooks/banking`
- **Eventos soportados**: `status_update`, `document_verified`, `risk_assessment`
- Registra el evento en `webhook_events` con direccion "incoming"

### Webhook Saliente
- `WebhookWorker` envia POST a URL configurable en cada cambio de estado
- Registra intentos, respuestas y estado (pending/sent/failed)
- Configurable via `WEBHOOK_URL` env var

## Estrategia de Cache

### Tecnologia: Cachex (ETS-backed)
| Dato cacheado | TTL | Invalidacion |
|---------------|-----|-------------|
| Solicitud por ID | 5 min | Al actualizar la solicitud |
| Lista de solicitudes | 1 min | Al crear/actualizar cualquier solicitud |
| Config de pais | 1 hora | Manual |

### Estrategia de invalidacion
- **Write-through**: Al modificar una solicitud, se invalida su cache y el cache de listas
- **TTL-based**: Datos expiran automaticamente despues del TTL
- **Cache-aside**: Si el dato no esta en cache, se consulta DB y se guarda

## Seguridad

### Autenticacion
- JWT via Guardian con tokens en header `Authorization: Bearer <token>`
- Passwords hasheados con PBKDF2 (pbkdf2_elixir)
- Endpoints protegidos con pipeline de autenticacion

### Proteccion de PII
- Documentos de identidad se enmascaran en respuestas API (solo ultimos 4 caracteres visibles)
- Banking info sanitizada antes de almacenar (se remueven campos sensibles)
- Logs no exponen datos sensibles completos

### Autorizacion
- Roles: admin y analyst
- Endpoints API protegidos por JWT

## Concurrencia

### Diseno para concurrencia
- **Optimistic Locking**: Campo `lock_version` en solicitudes previene actualizaciones concurrentes conflictivas
- **Oban queues**: Multiples workers procesan en paralelo con concurrencia configurable
- **PubSub**: Broadcast de eventos a todas las conexiones LiveView activas
- **BEAM OTP**: Cada conexion LiveView es un proceso Erlang aislado

### Escalabilidad horizontal
- Multiples instancias pueden procesar jobs de Oban simultaneamente (row-level locking en PostgreSQL)
- LiveView escala con el numero de nodos via distributed PubSub
- Stateless JWT permite balanceo de carga

## Escalabilidad y Grandes Volumenes

### Indices recomendados (implementados)
```sql
-- Indices simples para queries frecuentes
CREATE INDEX idx_applications_country ON credit_applications (country);
CREATE INDEX idx_applications_status ON credit_applications (status);
CREATE INDEX idx_applications_date ON credit_applications (application_date);
CREATE INDEX idx_applications_document ON credit_applications (identity_document);

-- Indice compuesto para filtros combinados
CREATE INDEX idx_applications_country_status ON credit_applications (country, status);

-- Indice parcial para solicitudes activas (excluye terminales)
CREATE INDEX idx_active_applications ON credit_applications (status)
  WHERE status NOT IN ('rejected', 'disbursed');

-- Audit logs
CREATE INDEX idx_audit_logs_application ON audit_logs (application_id);
CREATE INDEX idx_audit_logs_date ON audit_logs (inserted_at);
```

### Particionamiento (estrategia propuesta)
Para millones de registros, particionar `credit_applications` por:
1. **Rango de fecha** (`application_date`): particiones mensuales
2. **Pais** (`country`): sub-particiones por pais dentro de cada mes

```sql
-- Ejemplo de particionamiento por rango
CREATE TABLE credit_applications (
  -- ... campos ...
) PARTITION BY RANGE (application_date);

CREATE TABLE credit_applications_2026_01
  PARTITION OF credit_applications
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
```

### Consultas criticas y optimizacion
1. **Listado filtrado**: Indice compuesto (country, status) cubre el 90% de queries
2. **Busqueda por documento**: Indice en identity_document
3. **Solicitudes activas**: Indice parcial excluye estados terminales
4. **Paginacion**: Cursor-based pagination (por `inserted_at` + `id`) en lugar de OFFSET

### Archivado
- Solicitudes en estado terminal (rejected, disbursed) > 6 meses pueden moverse a tabla de archivo
- Implementable con pg_partman para gestion automatica de particiones
- Audit logs > 1 ano pueden comprimirse y moverse a cold storage

## API REST

### Autenticacion
```bash
# Registrar usuario
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secret123"}'

# Login
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@creditsystem.com", "password": "admin123"}'
```

### Solicitudes (requieren JWT)
```bash
TOKEN="<jwt_token>"

# Listar solicitudes
curl http://localhost:4000/api/applications \
  -H "Authorization: Bearer $TOKEN"

# Listar por pais
curl "http://localhost:4000/api/applications?country=MX" \
  -H "Authorization: Bearer $TOKEN"

# Crear solicitud
curl -X POST http://localhost:4000/api/applications \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "country": "MX",
    "full_name": "Juan Perez",
    "identity_document": "PEJJ900101HDFRRL09",
    "requested_amount": "100000",
    "monthly_income": "40000"
  }'

# Ver solicitud
curl http://localhost:4000/api/applications/<id> \
  -H "Authorization: Bearer $TOKEN"

# Actualizar estado
curl -X PATCH http://localhost:4000/api/applications/<id>/status \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "approved"}'
```

### Webhook entrante
```bash
curl -X POST http://localhost:4000/api/webhooks/banking \
  -H "Content-Type: application/json" \
  -d '{
    "application_id": "<id>",
    "event_type": "document_verified",
    "source": "banking_provider"
  }'
```

## Despliegue Kubernetes

Los manifiestos YAML estan en `k8s/`:
- `deployment.yaml`: Deployment para web (3 replicas) y workers (2 replicas)
- `service.yaml`: ClusterIP services
- `ingress.yaml`: Ingress con soporte WebSocket para LiveView
- `configmap.yaml`: Variables de entorno

### Aplicar manifiestos
```bash
kubectl create namespace credit-system
kubectl apply -f k8s/
```

### Consideraciones
- Secrets deben crearse manualmente (no incluidos por seguridad)
- Workers separados del web server para escalado independiente
- Ingress configurado con soporte WebSocket para LiveView
- Resources requests/limits definidos para cada pod

## Tests

```bash
# Correr todos los tests
make test

# Tests incluidos:
# - Validacion de CURP (Mexico)
# - Validacion de CC (Colombia)
# - Reglas de negocio por pais
# - State machine transitions
# - Page controller
# - Error views
```

## Supuestos

1. Los proveedores bancarios son simulados (mock) con latencia aleatoria
2. Los webhooks salientes fallan gracefully si no hay receptor
3. El tipo de cambio y moneda se manejan por pais (MXN/COP)
4. Un termino de 12 meses se asume para calcular pago mensual en MX
5. La autenticacion del webhook entrante se basa en el endpoint (en produccion se usaria HMAC)
6. Los seeds crean datos de ejemplo para demostrar funcionalidad
