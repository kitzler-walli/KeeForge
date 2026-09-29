<p align="center">
  <img src="../../.github/assets/NextPass-icon-1024.png" alt="Icono de la app NextPass" width="128" />
</p>

<h1 align="center">NextPass</h1>

<p align="center">
  <a href="../../README.md">English</a> | <a href="README.de.md">Deutsch</a> | <a href="README.fr.md">Français</a> | Español | <a href="README.zh-Hans.md">简体中文</a> | <a href="README.zh-Hant.md">繁體中文</a> | <a href="README.ja.md">日本語</a>
</p>

<p align="center">
  Un gestor de KeePass gratuito y de código abierto para iPhone, iPad, Mac y Apple Watch.
  <br />
  SwiftUI nativo, almacenamiento local primero, autorrelleno, llaves de acceso, TOTP, sincronización con Nextcloud y WebDAV, y una extensión de navegador para Brave y Chrome.
</p>

<p align="center">
  <img alt="Requiere iOS 18.0 o posterior" src="https://img.shields.io/badge/iOS-18.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="Requiere macOS 15.0 o posterior" src="https://img.shields.io/badge/macOS-15.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <a href="../../LICENSE">
    <img alt="Licencia: GPLv3" src="https://img.shields.io/badge/license-GPLv3-blue?style=for-the-badge" />
  </a>
</p>

## ¿Por qué NextPass?

NextPass es un cliente nativo de KeePass para iPhone, iPad y Mac, pensado para quienes quieren que su bóveda siga siendo suya. Abra bases de datos `.kdbx` desde archivos locales, Nextcloud, WebDAV o FTP en todas las plataformas, y desde iCloud Drive y otros proveedores de la app Archivos en iPhone y iPad; desbloquee con contraseña maestra, archivo de clave o biometría; y después explore, busque, edite, guarde y autorrellene sin entregar su bóveda a un servicio de contraseñas alojado.

NextPass aún no está en el App Store; las compilaciones llegan a los testers mediante TestFlight.

> [!WARNING]
> **Pruebe con una copia de su base de datos, no con su bóveda principal.** Las compilaciones de prueba abren sus archivos `.kdbx` reales.

## Funciones destacadas

| Área | Qué hace NextPass |
| --- | --- |
| **Compatibilidad con KeePass** | Lee y escribe bases KDBX 4.x con cifrado AES-256, ChaCha20 o Twofish y AES-KDF, Argon2d o Argon2id. También abre bases KDBX 3.1 en modo de solo lectura. |
| **Edición local primero** | Cree, edite, mueva, combine y elimine entradas y grupos; y guarde con detección de conflictos, copias de seguridad con marca de tiempo y conservación del historial de entradas y del XML desconocido. |
| **Bases de datos nuevas** | Cree bases KDBX 4.x nuevas en local o en un servidor Nextcloud, WebDAV o FTP. |
| **Claves compuestas** | Desbloquee con contraseña, archivo de clave o ambos, incluidos archivos de clave binarios, hexadecimales, XML v1/v2 (`.key`/`.keyx`) y arbitrarios. |
| **Autorrelleno** | Autorrelleno nativo de contraseñas en apps y navegadores, con desbloqueo biométrico; en iPhone y iPad, además, sugerencias de QuickType y creación de entradas desde la extensión. |
| **Llaves de acceso** | Guarde y use llaves de acceso FIDO2/WebAuthn en su base KeePass, en campos compatibles con KeePassXC — añadidas a una entrada de inicio de sesión existente o a una entrada nueva en el grupo que elija. |
| **Extensión de navegador** | En el Mac, una extensión para Brave y Chrome muestra las entradas del sitio abierto, busca en toda la base y rellena el inicio de sesión. La base se queda en NextPass, y cada navegador debe aprobarse con un código coincidente. |
| **TOTP** | Códigos de un solo uso con cuenta atrás y copia, configurados desde códigos QR o enlaces de configuración, además del autorrelleno de códigos de verificación en iOS 18+ y Mac. |
| **Apple Watch** | Las entradas con la etiqueta «Apple Watch» se copian al reloj, cuyos códigos de verificación siguen funcionando cuando el iPhone está fuera de alcance. |
| **Sincronización en la nube** | Inicie sesión en Nextcloud desde el navegador o conecte cualquier servidor WebDAV o FTP, con sincronización de lectura y escritura en todas las plataformas. |
| **Adjuntos** | Vea los adjuntos de las entradas de KeePass, previsualice los archivos compatibles con Vista rápida y compártalos desde archivos temporales protegidos y de corta duración. La edición de adjuntos aún no está disponible. |
| **Nativo en cada pantalla** | Navegación enfocada en iPhone, un espacio de trabajo en vista dividida en iPad y una app nativa para Mac con menús, comandos y Touch ID. |
| **Seguridad** | Cifrado AES-GCM de los secretos en memoria, espera creciente tras desbloqueos fallidos, límites contra bombas de descompresión y comparación HMAC en tiempo constante. |

## Privacidad

NextPass no incluye analítica, telemetría en segundo plano ni SDK de informes de fallos. Los datos de la bóveda se quedan en el dispositivo y en las ubicaciones de almacenamiento que usted elija. El acceso a la red se limita a los servidores que conecte, la descarga opcional de iconos de sitios mediante DuckDuckGo, las compras opcionales en el App Store para las propinas y el formulario de comentarios de la app cuando envíe un mensaje de forma explícita. La app para Mac también escucha en 127.0.0.1 para su extensión de navegador, y solo si usted lo activa; nada fuera de su Mac puede alcanzarla.

En iPhone y iPad, los secretos copiados se marcan como solo locales para que no pasen por el Portapapeles universal. macOS no ofrece esa exclusión, así que los secretos copiados pueden seguir su ajuste del Portapapeles universal; NextPass los marca como ocultos y borra su entrada del portapapeles al poco tiempo o al bloquear la base. NextPass también protege las vistas previas del selector de apps en iPhone y iPad. El bloqueo de capturas de pantalla en Mac se ofrece en la medida de lo posible y puede no impedir todas las capturas o grabaciones.

## Seguridad de los datos

NextPass se toma muy en serio la seguridad de los datos: un gestor de contraseñas nunca debe dañar su bóveda ni perder parte de ella sin avisar. Antes de publicar cualquier cambio, pruebas automáticas verifican que:

- **No se pierde nada al guardar.** Cada tipo de cambio se guarda y se vuelve a leer pieza por pieza: contraseñas, notas, adjuntos, historial de entradas e incluso datos de otras apps de KeePass que NextPass no reconoce deben volver exactamente como entraron.
- **Su archivo está protegido antes de tocarlo.** NextPass se niega a sobrescribir cambios hechos en otro lugar mientras tenía el archivo abierto, crea una copia de seguridad con marca de tiempo antes de cada guardado y rechaza las bases dañadas en lugar de cargar datos parciales.
- **Un programa independiente lo confirma.** Cada versión debe superar una verificación en la que KeePassXC — una app de KeePass muy usada que no comparte código con NextPass — abre bases escritas por NextPass, descifra las contraseñas y confirma que los adjuntos coinciden bit a bit. Las bases creadas por otro software de KeePass también deben abrirse en NextPass y seguir siendo legibles en otras apps después de que NextPass las guarde.

Para los más curiosos, el conjunto de pruebas se describe en [`KeeForgeTests/AGENTS.md`](../../KeeForgeTests/AGENTS.md) y la verificación previa a cada versión en [`ci_scripts/README.md`](../../ci_scripts/README.md) (en inglés).

## Orígenes

NextPass es un fork de [KeeForge](https://github.com/KeeForge/KeeForge), la app de KeePass de código abierto de crazytan y sus colaboradores. Las carpetas de código, los targets de Xcode y los tipos de Swift aún llevan ese nombre.

## Mapa del proyecto

```text
KeeForge/             # Código compartido de la app
├── App/              # Punto de entrada, shell raíz adaptable, ciclo de vida de escenas
├── Extensions/       # Utilidades compartidas de compatibilidad entre plataformas
├── Models/           # Lector/escritor KDBX, criptografía, borrador de edición, TOTP, llaves de acceso
├── Resources/        # Catálogos de cadenas y de recursos
├── Services/         # Persistencia, sincronización en la nube, llavero, marcadores, adjuntos, autorrelleno, puente del navegador
├── ViewModels/       # Lista de bases, desbloqueo, guardado, búsqueda, orden, estado TOTP
├── Views/            # Pantallas SwiftUI, editor, ajustes, propinas, controles reutilizables
AutoFillExtension/    # Proveedor de credenciales, autenticación con llaves de acceso, creación de credenciales
BrowserExtension/     # La extensión para Brave y Chrome
KeeForgeMac/          # Configuración y entitlements de la app nativa para macOS
KeeForgeWatch/        # App para Apple Watch
KeeForgeMacUITests/   # Pruebas XCUITest de la app para macOS
KeeForgeTests/        # Pruebas unitarias
KeeForgeUITests/      # Pruebas XCUITest
TestFixtures/         # Bases .kdbx y archivos de clave de ejemplo
Vendor/               # Paquete Swift de Twofish incluido
ci_scripts/           # Scripts de arranque de Xcode Cloud y de verificación de versiones
scripts/              # Herramientas de desarrollo locales
```

## Documentación

- [`CHANGELOG.md`](../../CHANGELOG.md) – historial de versiones
- [`ROADMAP.md`](../../ROADMAP.md) – trabajo previsto y prioridades abiertas
- [`AGENTS.md`](../../AGENTS.md) – contexto para agentes de código
- [`KeeForge/README.md`](../../KeeForge/README.md) – arquitectura del target de la app
- [`AutoFillExtension/AGENTS.md`](../../AutoFillExtension/AGENTS.md) – restricciones de la extensión y notas sobre el código compartido
- [`BrowserExtension/README.md`](../../BrowserExtension/README.md) – instalar y usar la extensión de navegador
- [`SECURITY.md`](../../SECURITY.md) – política de divulgación de vulnerabilidades
- [`docs/macos-security-notes.md`](../../docs/macos-security-notes.md) – modelo de seguridad de macOS, límites de la plataforma y mitigaciones
- [`docs/`](../../docs/) – especificaciones, auditorías y documentos de diseño extensos

Aparte de este README y [`CONTRIBUTING.es.md`](CONTRIBUTING.es.md), la documentación para desarrolladores se mantiene solo en inglés.

## Soporte

- Código fuente e incidencias: [git.kw.at/stephan/nextpass](https://git.kw.at/stephan/nextpass)

## Contribuir

Consulte [`CONTRIBUTING.es.md`](CONTRIBUTING.es.md) para conocer los requisitos de compilación, cómo compilar desde el código fuente, el flujo de trabajo de pull requests, el requisito de firma del Developer Certificate of Origin, y los términos de licencia. Empiece por [`AGENTS.md`](../../AGENTS.md) y luego abra el `README.md` local de la carpeta más cercana al código que vaya a modificar.

## Licencia

NextPass tiene licencia GPLv3, como KeeForge antes que él. Consulte [`LICENSE`](../../LICENSE) para más detalles.
