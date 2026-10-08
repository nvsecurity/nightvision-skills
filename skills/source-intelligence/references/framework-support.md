# Framework Support Matrix

Detailed component coverage per language and framework for NightVision Source Intelligence.

## Python (`--lang python`)

### Django
- `django.urls`: `path`, `re_path`, `include`
- `django.views.generic.View` — class-based views
- `django.http.QueryDict`, `HttpRequest`

### Django REST Framework
- Generic views: `CreateAPIView`, `ListAPIView`, `RetrieveAPIView`, `DestroyAPIView`, `ListCreateAPIView`, `RetrieveUpdateAPIView`, `RetrieveUpdateDestroyAPIView`
- `APIView`, `GenericAPIView`
- Mixins: `CreateModelMixin`, `DestroyModelMixin`, `ListModelMixin`, `RetrieveModelMixin`, `UpdateModelMixin`
- `ModelViewSet`, `ReadOnlyModelViewSet`
- `Serializer`, `Field` classes
- `ExtendedDefaultRouter`, `ExtendedSimpleRouter`

### Flask
- `flask.Flask`, `flask.Blueprint`
- `flask.request` (args, cookies, files, form, headers)
- `flask.views.View`, `MethodView`

### Flask-RESTful
- `flask_restful.Api`, `flask_restful.Resource`

### FastAPI
- `fastapi.FastAPI`, `fastapi.APIRouter`
- `pydantic.BaseModel` for request/response models
- `fastapi.Response`, `HTTPException`
- `fastapi.Header`, `fastapi.Cookie`
- `fastapi.status`

### Starlette
- `starlette.applications.Starlette`, `starlette.routing.Router`
- Route tables: `Route`, `Mount`, `Host`, including nested entries and mounted ASGI apps
- `route`, `add_route`, `mount`, `host`
- Function handlers and `HTTPEndpoint` classes; WebSocket routes are recognized but not emitted

### Connexion
- Connexion 2.x and 3.x: `App`, `FlaskApp`, `AsyncApp`
- OpenAPI 3 and Swagger 2 documents passed to `add_api`, with document and call-site base paths
- Handler resolution via `operationId`, `x-openapi-router-controller`, `x-swagger-router-controller`, `RestyResolver`

## Java (`--lang java`)

### Spring Boot
- `@RestController`, `@Controller`
- `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping`
- `@RequestMapping`, `@PathVariable`, `@ResponseBody`
- `@RepositoryRestResource` — auto-generated CRUD routes
- `@RestResource`

### JAX-RS / Jersey
- `@GET`, `@POST`, `@PUT`, `@DELETE`, `@HEAD`, `@OPTIONS`
- `@Path`, `@PathParam`, `@QueryParam`, `@FormParam`
- `@ApplicationPath`
- `MediaType`, `@Context`

### Micronaut
- `@Controller`
- `@Get`, `@Post`, `@Put`, `@Delete`, `@Patch`, `@Head`, `@Options`, `@Trace`
- `@PathVariable`, `@QueryValue`, `@Header`, `@CookieValue`, `@Body`, `@Part`
- `@Consumes`, `@Produces`
- `@Secured`, `SecurityRule`

### Servlet and annotation components (library support, not a routing framework)
- `HttpServletRequest`, `HttpServletResponse` (`javax.servlet.http` and `jakarta.servlet.http`)
- `@DenyAll`, `@PermitAll`, `@RolesAllowed`
- Plain `@WebServlet` classes and `web.xml` servlet mappings are not route sources; only JAX-RS servlets registered in `web.xml` are followed

## JavaScript / TypeScript (`--lang js`)

### Express
- `express.Router()`, `app.use()`, `app.route()`
- HTTP verbs: `get`, `post`, `put`, `patch`, `delete`, `all`
- `req.params`, `req.body`, `req.query`
- `app.listen()`

### NestJS
- `@nestjs/common`: `Controller`, `Module`, `Injectable`
- `@nestjs/core`: `DynamicModule`, `NestFactory.create`, `RouterModule.register`
- `setGlobalPrefix`, `listen`

### Fastify
- `@fastify/autoload`
- HTTP verbs: `get`, `head`, `post`, `put`, `delete`, `options`, `patch`
- `fastify.route`, `fastify.register`
- `fastify.listen`, `fastify.ready`

## C# (`--lang csharp`, alias `dotnet`)

### ASP.NET Core
- **Controllers**: `ApiController`, `Controller`, `ControllerBase`
- **HTTP attributes**: `HttpGet`, `HttpPost`, `HttpPut`, `HttpDelete`, `HttpPatch`, `HttpHead`, `HttpOptions`
- **Parameter binding**: `FromBody`, `FromHeader`, `FromQuery`, `FromRoute`
- **Minimal APIs**: `IEndpointRouteBuilder`, `MapControllers()`, `MapGroup()`
- **Auth**: `AddJwtBearer`, `AddCookie`, `AddOAuth`, `AddOpenIdConnect`, `Authorize`, `AllowAnonymous`
- **Config**: `WebApplication`, `WebApplicationBuilder`, `UseEndpoints()`, `UsePathBase()`

### Legacy ASP.NET (.NET Framework)
- ASP.NET MVC 5: `System.Web.Mvc` controllers, attribute routes, `RouteConfig.RegisterRoutes`
- Web API 2: `System.Web.Http.ApiController`, attribute routes, `WebApiConfig.Register`; controllers without a route use `{controller}/{action}`
- `Web.config` `<authentication mode="Forms">` and `mode="Windows"` become security schemes

## Go (`--lang go`)

### Gin
- `gin.New()`, `gin.Default()`
- Route groups: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`, `ANY`, `Handle`, `Group`
- Binding: `BindJSON`, `ShouldBind`, `ShouldBindJSON`
- Parameters: `Query`, `Param`, `PostForm`, `Cookie`

### Echo
- `echo.New()`
- `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS`, `HEAD`, `CONNECT`, `TRACE`, `Any`, `Match`, `Add`, `Group`
- `Context.Param`, `Context.QueryParam`, `Context.FormValue`, `Context.Bind`

### Fiber v2
- `fiber.New()`
- `Get`, `Post`, `Put`, `Delete`, `Patch`, `Head`, `Options`, `Connect`, `Trace`, `All`, `Add`, `Group`, `Route`
- `Ctx.Params`, `Ctx.Query`, `Ctx.FormValue`, `Ctx.BodyParser`, `Ctx.QueryParser`
- A Fiber v3 import is recognized but analyzed with v2 semantics

### chi
- `chi.NewRouter()`, `chi.NewMux()`, `chi.URLParam`
- `Get`, `Post`, `Put`, `Delete`, `Patch`, `Head`, `Options`, `Connect`, `Trace`, `HandleFunc`, `Handle`, `Method`, `MethodFunc`
- `Route`, `Group`, `Mount`, `With`

### gorilla/mux
- `mux.NewRouter()`
- `Router.HandleFunc`, `Router.Handle`, `Router.PathPrefix`, `Router.Path`
- `Route.Subrouter`, `Route.Methods`, `Route.Queries`, `Route.Handler`, `Route.HandlerFunc`

### httprouter
- `httprouter.New()`
- `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS`

### net/http (standard library)
- `http.HandleFunc`, `http.Handle`, `http.NewServeMux`, `ServeMux.HandleFunc`, `ServeMux.Handle`, including Go 1.22 method and wildcard patterns
- `http.Request`: `FormValue`, `PostFormValue`, `Cookie`, `PathValue`
- `http.ResponseWriter`
- `http.Server`, `ListenAndServe`
- Third-party routers other than the ones listed above are not modeled

## PHP (`--lang php`)

### Laravel
- Routing: `Route::get`, `post`, `put`, `patch`, `delete`, `options`, `head`, `any`, `match`, `resource`, `apiResource`, `singleton`, `apiSingleton`, `redirect`, `view`, `fallback`
- Groups: `Route::prefix`, `middleware`, `name`, `domain`, `controller`, `namespace`, `group`; resource modifiers `only`, `except`, `shallow`; parameter constraints `where*`
- Route files registered by `RouteServiceProvider` (Laravel 10) or `bootstrap/app.php` `withRouting` (Laravel 11+), including package, module and Porto layouts
- `Illuminate\Http\Request` input readers (`input`, `query`, `json`, `header`, `cookie`, `file`, `validate`, ...) and `FormRequest` rules for parameter names, types and required status
- Responses: `response()`, `response()->json`, `download`, `file`, `stream`, `noContent`, `redirect`, `view`, `abort`, `JsonResource`
- Auth: guards from `config/auth.php` (`session`, `token`, `sanctum`, `passport`) and the `auth` middleware with named guards (`auth:sanctum`, `auth:api`)
- Laravel only: Symfony, Slim, Lumen, CodeIgniter, Yii, Laminas and WordPress are not modeled

## Ruby (`--lang ruby`)

### Rails
- `ActionController::Base`
- Routing: `resources`, `resource`, `namespace`, `member`, `collection`
- HTTP verbs: `get`, `post`, `put`, `patch`, `delete`
- Strong parameters via `ActionController::Parameters`

### Grape
- `Grape::DSL::Routing`
- `resource`, `namespace`, `get`, `post`, `put`, `patch`, `delete`
- `mount`, `version`, `params`, `prefix`
