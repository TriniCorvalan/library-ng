# library-ng

Frontend Angular de la **biblioteca** (DUOC Full Stack III — Exp 2 Semana 3).

Gestiona libros consumiendo el microservicio [`library-fullstack3`](https://github.com/TriniCorvalan/library-fullstack3) y autenticación JWT vía [`ms-usuarios`](https://github.com/TriniCorvalan/ms-usuarios).

| Capacidad | Detalle |
|-----------|---------|
| Stack | Angular 21 (standalone), Bootstrap 5, RxJS |
| Lectura | Pública (`GET /books`, listado sin login) |
| Escritura | Requiere JWT (`POST` / `PUT` / `DELETE`) |
| Auth | Login en `ms-usuarios` (`:8081`); `library` valida el mismo `jwt.secret` |

## Arquetipo y patrones de diseño

### Arquetipo MVC

| Pieza | En este proyecto |
|-------|------------------|
| **Modelo** | Interfaces (`Book`, `Usuario`) + servicios HTTP (`BookService`, `AuthService`) |
| **Vista** | Templates HTML de `pages/` y `shared/` |
| **Controlador** | Componentes de página (`Books`, `BookForm`, `Login`) que orquestan formulario, rutas y llamadas al modelo |

Estructura por capas (mismo criterio que un arquetipo Angular tipo core / pages / shared):

```
src/app/
  core/          → modelo + infraestructura (constants, services, guards, interceptors)
  pages/         → pantallas (controladores + vistas)
  shared/        → UI reutilizable (header)
```

### Patrón Singleton

`AuthService` y `BookService` usan `@Injectable({ providedIn: 'root' })`: Angular crea **una sola instancia** compartida en toda la aplicación (inyección de dependencias).

### Patrón Observer

Los métodos de los servicios devuelven `Observable` de RxJS. Las páginas se **suscriben** a las respuestas HTTP (`HttpClient`) y reaccionan cuando llegan datos o errores. El `authInterceptor` también participa en el flujo de cada request.

## Rutas de la SPA

| Ruta | Acceso | Función |
|------|--------|---------|
| `/libros` | Público | Listado; botones de mutación solo con sesión |
| `/login` | Público | Login contra `ms-usuarios` |
| `/libros/nuevo` | Autenticado | Crear libro |
| `/libros/:id` | Autenticado | Editar libro |

Atributos del libro (iguales al microservicio): `id`, `title`, `author`, `year`, `genre`.

## Credenciales de prueba

| Email | Password | Origen |
|-------|----------|--------|
| `admin@foro.cl` | `Admin123!` | Seed de `ms-usuarios` |

## Cómo ejecutar (desarrollo local)

Necesitas tres procesos:

1. **ms-usuarios** (JWT) en `:8081`
2. **library** (CRUD libros) en `:8080`
3. **library-ng** con `ng serve` en `:4200`

```bash
# Terminal 1 — auth
cd "[...]/ms-usuarios"
./mvnw spring-boot:run

# Terminal 2 — libros
cd ../library
./mvnw spring-boot:run

# Terminal 3 — front
cd ../library-ng
npm start
```

Abrí http://localhost:4200

En desarrollo, las URLs del API están en `src/environments/environment.ts` (`localhost:8080` y `localhost:8081`).

## Cómo ejecutar con Docker

El `docker-compose.yml` de este proyecto levanta **library** + **library-ng**.  
`ms-usuarios` sigue corriendo en el host (puerto 8081); nginx del front hace proxy de `/auth/` hacia `host.docker.internal:8081` y de `/books` hacia el servicio `library`.

```bash
# Primero ms-usuarios en el host
cd "[...]/ms-usuarios"
./mvnw spring-boot:run

# Luego compose (desde library-ng)
cd ../../library-ng
docker compose up --build
```

| Servicio | URL |
|----------|-----|
| Frontend | http://localhost:8088 |
| API libros | http://localhost:8080/books |

Build de producción usa `environment.prod.ts` (rutas relativas `/books` y `/auth/...`).

## Flujo de autenticación (opción 2B) — solo local

1. El usuario inicia sesión en el front → `POST http://localhost:8081/auth/login`.
2. Se guarda el JWT en `localStorage`.
3. El interceptor agrega `Authorization: Bearer <token>` a las peticiones.
4. `library` valida el token con el **mismo** `jwt.secret` que `ms-usuarios`.
5. `GET` de libros no exige token; `POST` / `PUT` / `DELETE` sí (401 sin token).

En AWS **no** se despliega `ms-usuarios`: la demo pública es el listado (`GET /books`).

## Despliegue AWS Academy (EC2) — playbook

Misma idea que el manual del profesor: una EC2 con Nginx en el host, contenedores Docker
(`library` en `:8080`, `library-ng` en `:4000`) y despliegue por **Systems Manager** desde GitHub Actions.
Wallet Oracle en **S3**; credenciales en **Secrets Manager**.

Plantilla: [`ec2/library-ec2-stack.yml`](ec2/library-ec2-stack.yml).  
Workflow de este repo: [`.github/workflows/publish-ecr.yml`](.github/workflows/publish-ecr.yml).  
API: repo `library` → workflow **Test, publish and deploy API to EC2**.

### 1. Secreto Oracle

En Secrets Manager (misma región, ej. `us-east-1`), secreto tipo key/value:

| Clave | Valor |
|-------|--------|
| `DB_URL` | Alias TNS (ej. `tg243br3udtanbr0_tp`) |
| `DB_USERNAME` | Usuario del esquema |
| `DB_PASSWORD` | Contraseña |

Anotá el **ARN** completo.

### 2. Crear el stack (automatizado)

En **library-ng** → Settings → Variables, además de las del paso 4:

| Variable | Valor |
|----------|--------|
| `ORACLE_CREDENTIALS_SECRET_ARN` | ARN del secreto (también en este repo) |
| `ORACLE_WALLET_S3_KEY` | `Wallet.zip` (opcional; default) |
| `ORACLE_WALLET_S3_BUCKET` | vacío = el stack crea el bucket |
| `VPC_ID` / `PUBLIC_SUBNET_ID` | opcionales; si faltan, el script intenta detectar VPC default y una subred pública |

Luego: Actions → **Prepare EC2 CloudFormation stack** → Run workflow.

Eso ejecuta `ec2/prepare-stack.sh` con `ec2/library-ec2-stack.yml`. Al terminar, el resumen del job muestra `InstanceId`, bucket del wallet y `WebsiteUrl`.

Confirmá en **Systems Manager → Fleet Manager** que el nodo esté **Online** (UserData instala Docker/Nginx).

Alternativa manual: CloudFormation → Upload `ec2/library-ec2-stack.yml` con `CreateInstanceRole=false` y `LabInstanceProfile`.

### 3. Subir el wallet

Subí el ZIP original del wallet a S3 con la clave exacta de `WalletObjectKey`. No lo subas a GitHub.

### 4. Secrets y variables en GitHub

En **ambos** repos (`library` y `library-ng`) → Settings → Secrets and variables → Actions:

**Secrets (ambos):** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (sesión temporal Academy).

**Variables en ambos:**

| Variable | Valor |
|----------|--------|
| `AWS_REGION` | `us-east-1` |
| `EC2_INSTANCE_ID` | `InstanceId` |
| `AWS_ACCOUNT_ID` | `533267145144` (opcional) |

**Solo en `library`:**

| Variable | Valor |
|----------|--------|
| `ORACLE_CREDENTIALS_SECRET_ARN` | ARN del secreto |
| `ORACLE_WALLET_S3_BUCKET` | `WalletBucketName` |
| `ORACLE_WALLET_S3_KEY` | `WalletObjectKey` |

### 5. Desplegar (API primero, luego front)

1. Repo **library** → Actions → **Test, publish and deploy API to EC2** → rama `prepare-ecr-ecs` o `main`.
2. Smoke: `http://IP/books` → JSON array.
3. Repo **library-ng** → Actions → **Publish and deploy frontend to EC2**.
4. Abrí `WebsiteUrl` (`http://IP/`). El host Nginx enruta `/books` → API y `/` → front.

Si reiniciás la EC2 sin Elastic IP, la IP pública puede cambiar: actualizá desde la consola EC2 o el último deploy.

### Problemas frecuentes

| Síntoma | Qué revisar |
|---------|-------------|
| `NoCredentials` / perfil CLI | Usá `--profile fullstack3` (o el tuyo); las credenciales no están en `default` |
| Deploy-ec2 falla por `EC2_INSTANCE_ID` | Stack creado + variable seteada en el repo correcto |
| Wallet / Oracle | Bucket, clave, ZIP con `tnsnames.ora` en la raíz, alias = `DB_URL`, red Oracle |
| Instancia no Online en SSM | Perfil `LabInstanceProfile`, salida a Internet, agente SSM |
| Secrets expirados | Renová los tres en **ambos** repos |
