# Licencias locales

## Emisión y compilación

Genera una pareja Ed25519 en un equipo de administración desconectado. Guarda la clave privada fuera del repositorio, en almacenamiento cifrado y con acceso restringido:

```sh
dart run tool/license_issuer.dart keygen /ruta-segura/tienda-private.json /ruta-segura/tienda-public.txt
```

La clave pública se distribuye con el binario; la privada nunca. Antes de compilar define `LICENSE_PUBLIC_KEY` con el contenido de `tienda-public.txt`. En Windows, `compilar_instalador_premium.bat` y `compilar_instalador_premium_modern_exe.bat` la inyectan como `--dart-define`; si la variable no está definida, solicitan la ruta al archivo `tienda-public.txt`. El generador del EXE moderno compila Flutter antes de empaquetar. En otras plataformas, usa el mismo argumento en `flutter build`.

Para ejecutar o compilar Windows en modo debug usando una clave pública guardada fuera del repositorio:

```powershell
.\tool\run_windows_with_license_key.ps1 -PublicKeyPath C:\Users\Thonny\TiendaKeys\tienda-public.txt
.\tool\run_windows_with_license_key.ps1 -PublicKeyPath C:\Users\Thonny\TiendaKeys\tienda-public.txt -BuildOnly
```

El campo «Código de activación» no acepta el archivo ni el texto de la clave pública. Para activar, genera un código firmado `DK1...` con la clave privada para los valores de Instalación y Huella que muestra la app:

```powershell
dart run tool/license_issuer.dart issue C:\Users\Thonny\TiendaKeys\tienda-private.json <installation-id> <fingerprint> 365
```

Solicita al cliente los valores de Instalación y Huella del equipo visibles en Estado de licencia. Emite el código localmente:

```sh
dart run tool/license_issuer.dart issue /ruta-segura/tienda-private.json <installation-id> <fingerprint> 365
```

Usa `perpetual` en lugar de `365` para una licencia sin vencimiento. El código resultante se ingresa en la app y se valida sin conexión. Si se pierde la clave privada, no se podrán emitir más licencias para binarios que contengan su clave pública; conserva una copia de recuperación cifrada.

## Persistencia y alcance

La licencia es por instalación de la app, no por `store_id`; los locales administrados por una instalación comparten su licencia, pero sus datos comerciales siguen aislados por el esquema existente. SQLite guarda una copia y otra se conserva fuera del directorio de instalación (Windows: `%ProgramData%/DevKosmosyne/Tienda/<scope>/license`, donde `scope` deriva de la ruta de instalación). Actualizar o desinstalar la app no elimina deliberadamente ese archivo; otra copia instalada en una ruta distinta mantiene su propio scope.

Se guarda la Demo de 168 horas en UTC, ID de instalación, fingerprint, última hora observada y código firmado. El registro se ofusca y valida con checksum; las dos copias se reconcilian y, si una sigue válida, se recupera la otra. Si ambas se borran manualmente, un sistema exclusivamente local no puede probar que existió una Demo previa.

## Seguridad y límites

- Ed25519 impide fabricar o alterar códigos sin la clave privada. La app solo contiene la clave pública. El fingerprint usa MachineGuid en Windows, UUID de plataforma en macOS y machine-id en Linux, con hostname como fallback.
- La ofuscación XOR y el checksum no son cifrado resistente ni secreto criptográfico: un atacante que modifique el binario puede saltarse las comprobaciones. Para proteger el estado de un atacante local con acceso al equipo se requeriría hardware seguro o validación en un servicio.
- El reloj se compara con la última hora observada; un retroceso de más de cinco minutos invalida el estado. Cambios legítimos del reloj, reinstalaciones del sistema o cambios de hardware pueden requerir soporte.
- Sin conexión no existe revocación remota inmediata. El estado revocado solo puede conocerse cuando se instala un nuevo código firmado que indique revocación; no se afirma que un código activo pueda revocarse a distancia.
- La Demo sobrevive a borrado de preferencias y a la eliminación de una de sus copias, pero no a la eliminación deliberada de todos los datos locales o a una modificación del ejecutable.

Para una plataforma centralizada futura, conserva este contrato versionado de claims (`installationId`, `fingerprint`, `issuedAt`, `expiresAt`, `licenseId`, `revoked`) y las interfaces de servicio/persistencia. Se podría añadir sincronización y una lista de revocación firmada, manteniendo el modo local como caché o fallback, sin mezclar la licencia con el modelo de cada local.
