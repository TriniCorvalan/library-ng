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

## Flujo de autenticación (opción 2B)

1. El usuario inicia sesión en el front → `POST http://localhost:8081/auth/login`.
2. Se guarda el JWT en `localStorage`.
3. El interceptor agrega `Authorization: Bearer <token>` a las peticiones.
4. `library` valida el token con el **mismo** `jwt.secret` que `ms-usuarios`.
5. `GET` de libros no exige token; `POST` / `PUT` / `DELETE` sí (401 sin token).
