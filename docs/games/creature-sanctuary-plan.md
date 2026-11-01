# Creature Sanctuary — Plan completo

> Documento de producto y ejecución para transformar partes reutilizables de **Steal a Meme** y su **Forest Mode** en un incremental de colección de criaturas, producción, expediciones y defensa.
>
> Nombre provisional: **Creature Sanctuary**, **Wildbound Sanctuary** o **Critter Haven**.
>
> Este documento es un plan de trabajo. No significa que todas las funciones deban construirse antes de la primera prueba.

---

## 1. Resumen de la idea

El jugador construye un santuario para criaturas.

Durante el día:

```text
explora / consigue criaturas
→ las asigna a hábitats
→ producen recursos
→ mejora el santuario
→ desbloquea zonas y criaturas
```

Durante la noche:

```text
oleadas atacan el santuario
→ las criaturas defienden
→ el jugador coloca guardianes y usa habilidades
→ gana recompensas si sobrevive
```

El jugador debe decidir cómo usar cada criatura:

- Producción de recursos.
- Defensa.
- Expediciones.
- Evolución o fusión.
- Intercambio.
- Colección y logros.

La fantasía central es:

> **Construye un santuario vivo, descubre criaturas raras y haz que tu colección produzca y defienda por ti.**

---

## 2. Qué reutilizar del trabajo existente

### 2.1 De Steal a Meme

Revisar y extraer, sin copiar automáticamente la temática:

- Sistema de bases o parcelas.
- Huecos para unidades.
- Colocación de unidades en espacios.
- Producción de ingresos pasivos.
- Monedas y monedas secundarias.
- Mejoras de base.
- Sistema de protección/candado.
- Compra y entrega de unidades.
- Teletransporte y devolución segura de unidades.
- Sistemas de tienda.
- Daily spin, si sigue siendo útil.
- Mutaciones, convertidas en variantes o evoluciones.
- Temporadas y eventos.
- Rankings.
- Guardado con bloqueo y recuperación.
- Protección contra doble entrega de compras.
- Validación server-side de RemoteEvents.
- HUD, paneles y componentes de UI que sean genéricos.
- Pruebas realizadas en Studio.

### 2.2 Del Forest Mode

Revisar y reutilizar especialmente:

- Campamento/santuario.
- Ciclo día-noche.
- Oleadas.
- Carriles y waypoints.
- Enemigos con diferentes roles.
- Reclutamiento de criaturas.
- Guardianes que defienden puertas.
- Mejoras del núcleo y puertas.
- Torres y ataques automáticos.
- Cofres y recompensas.
- Reliquias.
- Eventos y jefes.
- Cooperación entre jugadores.
- Configuración separada del código.
- Generación de mapa.
- Optimización de partes y sombras.
- Pruebas de rendimiento.

### 2.3 Lo que no debe copiarse literalmente

- Memes o personajes con derechos.
- Nombres, iconos o estética de otros juegos.
- La presentación de Steal a Brainrot.
- Un sistema de robo como propuesta principal.
- Nombres como `Meme`, `Brainrot`, `Lucky Block` si no tienen sentido en el nuevo juego.
- Diseños, criaturas o terminology recognoscible de Pokémon/PokéRogue.

Se puede reutilizar la infraestructura técnica sin reutilizar la identidad comercial.

---

## 3. Identidad del juego

### 3.1 Pilares

1. **Colección:** siempre hay una criatura, variante o evolución que buscar.
2. **Decisiones:** una criatura no sirve para todo; el jugador decide dónde ponerla.
3. **Progreso visible:** el santuario cambia y mejora delante del jugador.
4. **Defensa:** la colección tiene una función durante las oleadas.
5. **Rejugabilidad:** expediciones, rarezas, eventos y prestigio.
6. **Producción barata:** la arquitectura debe permitir temas y criaturas nuevas sin reescribir todo.

### 3.2 Diferencia respecto a un simulador genérico

No debe ser solamente:

```text
comprar criatura → ganar monedas → comprar criatura mejor
```

Debe ser:

```text
conseguir criatura
→ decidir su hábitat y función
→ combinar producción y defensa
→ salir a expedición
→ arriesgar recursos por mejores recompensas
→ evolucionar la colección
→ mejorar el santuario
```

### 3.3 Diferencia respecto a un RPG completo

No necesita inicialmente:

- Combate por turnos complejo.
- Cientos de movimientos.
- Decenas de biomas detallados.
- Campaña larga.
- Un sistema de batalla equivalente a Rogue Tamer.

Puede usar combate automático o defensa por oleadas para reducir el coste de contenido.

---

## 4. Bucle de juego

### 4.1 Bucle de 30 segundos

```text
ver recursos / recoger recompensa
→ comprar o reclamar una mejora
→ colocar o mejorar una criatura
→ ver producción o defensa aumentada
```

### 4.2 Bucle de 5 minutos

```text
completar una expedición corta
→ encontrar recursos, huevo o criatura
→ volver al santuario
→ decidir cómo usar la recompensa
```

### 4.3 Bucle de 15–20 minutos

```text
preparar el santuario
→ sobrevivir una noche
→ ganar cofre o reliquia
→ desbloquear una mejora
→ aumentar la capacidad del santuario
```

### 4.4 Bucle de largo plazo

```text
completar colecciones
→ evolucionar criaturas
→ desbloquear hábitats
→ superar zonas y jefes
→ hacer prestigio
→ volver con ventajas permanentes
```

---

## 5. Sistemas principales

## 5.1 Santuario

Cada jugador tiene una parcela con:

- Núcleo o tótem.
- Hábitats.
- Huecos de producción.
- Huecos de defensa.
- Banco de criaturas.
- Estación de evolución/fusión.
- Tabla de expediciones.
- Cofres o recompensas.
- Puertas y torres.

### Mejoras iniciales

- Capacidad de criaturas.
- Número de hábitats.
- Producción base.
- Vida del núcleo.
- Número de guardianes.
- Daño de torres.
- Velocidad de expedición.
- Probabilidad de rareza.

## 5.2 Criaturas

Cada criatura debería ser un dato configurable, no lógica codificada individualmente.

```lua
return {
    Id = "mist_fox",
    DisplayName = "Zorro de Bruma",
    Rarity = "Rare",
    Habitat = "Forest",
    Production = 5,
    Defense = 12,
    ExpeditionPower = 8,
    Abilities = {"MistAura"},
    Evolution = "spectral_fox",
    Tags = {"Forest", "Mist"},
}
```

Atributos sugeridos:

- Id interno.
- Nombre visible.
- Rareza.
- Hábitat preferido.
- Producción.
- Poder defensivo.
- Poder de expedición.
- Habilidad pasiva.
- Evolución.
- Variante visual.
- Coste de mantenimiento, si se utiliza.
- Tags para sinergias.
- Asset/modelo/sprite.

### Roles

- Productora: genera esencia.
- Guardiana: defiende el santuario.
- Exploradora: mejora expediciones.
- Apoyo: aumenta otras criaturas.
- Rara: tiene una regla especial.
- Jefe: recompensa de evento o zona.

## 5.3 Hábitats

Hábitats iniciales:

- Bosque.
- Pantano.
- Montaña.

Futuros:

- Cueva.
- Desierto.
- Ruinas.
- Corazón corrupto.
- Cielo flotante.

Cada hábitat puede dar bonificaciones:

```text
criatura en hábitat correcto: +25% producción
criatura compatible: habilidad activada
criatura incompatible: producción normal o penalización pequeña
```

Evitar penalizaciones frustrantes en el MVP. Es mejor recompensar colocaciones buenas que castigar las malas.

## 5.4 Producción

Moneda inicial:

- **Esencia** o **Núcleos**.

La producción debe poder configurarse:

```text
Income = BaseProduction × RarityMultiplier × HabitatBonus × UpgradeMultiplier
```

No meter demasiadas monedas al principio.

MVP:

- Esencia.
- Fragmentos de evolución, como recurso secundario opcional.

Futuro:

- Reliquias.
- Materiales.
- Valas o tickets de expedición.

## 5.5 Expediciones

Una expedición es una actividad corta que evita que el juego sea solo esperar.

MVP:

- Elegir una zona.
- Elegir hasta 3 criaturas.
- Esperar o jugar una secuencia corta.
- Obtener recursos, huevos o criaturas.

Opciones:

1. Expedición automática de 60–180 segundos.
2. Minijuego muy corto.
3. Camino con 3 decisiones.
4. Encuentro de criatura rara.
5. Expedición cooperativa futura.

Cada expedición debe tener:

- Coste.
- Duración.
- Poder recomendado.
- Recompensas.
- Riesgo.
- Tabla de rarezas.

## 5.6 Defensa nocturna

Durante la noche:

- Aparecen enemigos por carriles.
- Las criaturas guardianas atacan automáticamente.
- El jugador puede activar una habilidad limitada.
- El núcleo debe sobrevivir.
- La recompensa aumenta con la dificultad.

MVP:

- Un mapa.
- Un carril o pocos carriles.
- Tres tipos de enemigo.
- Una oleada final.
- Un jefe opcional.

Futuro:

- Varias puertas.
- Climas.
- Enemigos con habilidades.
- Reliquias.
- Eventos nocturnos.
- Jefes de guarida.

## 5.7 Evolución y fusión

Opciones:

- Evolución por nivel de colección.
- Evolución por fragmentos.
- Fusión de duplicados.
- Variantes brillantes o mutadas.
- Evoluciones de evento.

La fusión debe evitar destruir accidentalmente la única copia de una criatura importante. Pedir confirmación y usar protección para favoritos.

## 5.8 Prestigio / renacimiento

Cuando el jugador alcanza una meta:

```text
reinicia producción y mejoras temporales
→ conserva colección o parte de ella
→ recibe una ventaja permanente
```

Ejemplos:

- +5% producción permanente.
- Más capacidad de expedición.
- Desbloqueo de una rareza.
- Huevos especiales.
- Cosméticos del santuario.

No añadirlo hasta que el bucle básico sea divertido.

## 5.9 Social

MVP:

- Visitar santuarios.
- Ver colección de otros jugadores.
- Leaderboard.
- Invitar a una expedición futura.

Futuro:

- Intercambio seguro.
- Expediciones cooperativas.
- Eventos de servidor.
- Desafíos de defensa.
- Mercado limitado.

Evitar comercio libre al principio por riesgo de duplicación, fraude y economía rota.

---

## 6. Contenido del MVP

### Objetivo

Crear una versión jugable en la que un jugador pueda entender el concepto y jugar 15–30 minutos.

### Contenido

- 12 criaturas.
- 3 hábitats.
- 1 santuario.
- 1 zona de expedición.
- 1 ciclo día/noche.
- 1 moneda principal.
- 5–8 mejoras.
- 3 tipos de enemigo.
- 1 jefe sencillo.
- 1 evolución o fusión.
- 1 cofre de recompensa.
- 1 leaderboard.
- Guardado básico.
- UI para PC y móvil.

### No incluir en MVP

- 100 criaturas.
- 34 biomas.
- Combate por turnos completo.
- Intercambio entre jugadores.
- Mercado.
- Pase de temporada.
- 10 monedas.
- PvP.
- Clases complejas.
- Múltiples mundos.
- Fábrica completa.

### Criterio de terminado del MVP

El MVP está listo para test cuando:

- Un jugador nuevo entiende qué hacer sin explicación externa.
- Consigue su primera criatura rápidamente.
- Coloca una criatura y ve el efecto.
- Puede mejorar el santuario.
- Puede realizar una expedición.
- Puede sobrevivir o perder una noche.
- El progreso se guarda.
- No hay errores graves en servidor o cliente.
- Funciona en móvil básico.

---

## 7. Arquitectura técnica

## 7.1 Organización sugerida

```text
ReplicatedStorage/
├── Shared/
│   ├── Types.lua
│   ├── Constants.lua
│   ├── CreatureDefinitions.lua
│   ├── HabitatDefinitions.lua
│   ├── ExpeditionDefinitions.lua
│   ├── UpgradeDefinitions.lua
│   └── EconomyConfig.lua
├── Remotes/
└── Packages/

ServerScriptService/
├── Services/
│   ├── PlayerDataService.lua
│   ├── CreatureService.lua
│   ├── HabitatService.lua
│   ├── IncomeService.lua
│   ├── ExpeditionService.lua
│   ├── DefenseService.lua
│   ├── UpgradeService.lua
│   ├── EvolutionService.lua
│   ├── RewardService.lua
│   ├── MonetizationService.lua
│   └── AnalyticsService.lua
├── Systems/
└── ServerMain.server.lua

StarterPlayer/
└── StarterPlayerScripts/
    ├── Controllers/
    └── ClientMain.client.lua

StarterGui/
├── HUD
├── SanctuaryUI
├── CreatureUI
├── ExpeditionUI
├── UpgradeUI
└── TutorialUI

Workspace/
├── SanctuaryTemplate
├── ExpeditionMap
└── DefenseMap
```

## 7.2 Datos persistentes

Guardar solo datos necesarios:

```lua
{
    SchemaVersion = 1,
    Essence = 0,
    PermanentCurrency = 0,
    Creatures = {},
    OwnedVariants = {},
    PlacedCreatures = {},
    UnlockedHabitats = {"Forest"},
    Upgrades = {},
    BestNight = 0,
    ExpeditionStats = {},
    TutorialVersion = 1,
    Settings = {},
}
```

Requisitos:

- Versionado de esquema.
- Migraciones.
- Reintentos controlados.
- Bloqueo de sesión.
- Guardado al salir.
- Guardado periódico.
- No confiar en datos del cliente.
- No duplicar recompensas después de una reconexión.

## 7.3 Seguridad

Validar en servidor:

- Costes.
- Propiedad de criaturas.
- Colocación.
- Recompensas.
- Duración de expediciones.
- Evoluciones.
- Compras.
- Rebirth.
- Intercambios futuros.

El cliente solo solicita una acción. El servidor decide si es válida.

## 7.4 Configuración

Separar números y contenido del código:

```text
CreatureDefinitions
HabitatDefinitions
EnemyDefinitions
WaveDefinitions
UpgradeDefinitions
RewardTables
EconomyConfig
MonetizationConfig
FeatureFlags
```

Usar feature flags para probar sistemas sin romper el juego:

```lua
FeatureFlags = {
    DefenseEnabled = true,
    ExpeditionsEnabled = true,
    TradingEnabled = false,
    PrestigeEnabled = false,
}
```

---

## 8. Monetización

No monetizar agresivamente antes de comprobar el bucle.

### Opciones compatibles con el juego

- Más espacio de colección.
- Más huecos de hábitat.
- Cosméticos del santuario.
- Efectos visuales.
- Pase de comodidad.
- Auto-collect como comodidad razonable.
- Boost temporal no obligatorio.
- Tickets de expedición opcionales.
- Servidores privados.
- Pase de temporada, solo si hay contenido real.

### Evitar

- Pagar para ganar automáticamente todas las defensas.
- Criaturas exclusivas imposibles de conseguir sin pagar.
- Esperas artificiales abusivas.
- Cinco monedas premium confusas.
- Ventajas que destruyan el intercambio.
- Probabilidades ocultas o engañosas.

### Primera monetización de prueba

Usar solo 2–3 productos:

1. Pase de comodidad.
2. Producto de boost temporal.
3. Cosmético o paquete visual.

Los IDs reales deben estar configurados antes de una publicación pública.

---

## 9. Arte y pipeline Blender

### Estilo recomendado

- Low-poly estilizado.
- Siluetas claras.
- Colores por hábitat.
- Pocos materiales.
- Variantes reutilizables.
- Escala consistente.

### Producción

```text
lista de criaturas
→ ficha visual
→ blockout Blender
→ revisión de silueta
→ materiales simples
→ render/sprite o modelo Roblox
→ optimización
→ importación
→ prueba en móvil
```

### Kit visual inicial

- 12 criaturas.
- 3 hábitats.
- 6 enemigos.
- 3 estructuras.
- 10 iconos.
- 3 botones de recursos.
- 1 logo.
- 1 thumbnail.
- 1 imagen de icono.

### Reglas

- Guardar los `.blend` originales.
- Exportar a carpetas nuevas.
- No sobrescribir assets aprobados.
- Revisar licencias de modelos externos.
- Usar Aseprite o LibreSprite para limpieza de sprites.
- No producir cientos de assets antes de validar el estilo.

---

## 10. Fases de desarrollo

### Fase 0 — Decisión y preparación

- Copiar el proyecto original.
- Guardar/publicar una versión segura de Steal a Meme.
- Exportar scripts y módulos a Git.
- Identificar sistemas genéricos y temáticos.
- Crear un nuevo place o universo de prueba.
- Escribir los 12 diseños iniciales de criaturas.

Salida:

```text
copia segura + repositorio de código + lista de módulos reutilizables
```

### Fase 1 — Santuario y producción

- Crear una parcela.
- Colocar hábitats.
- Obtener una criatura.
- Colocarla en un hueco.
- Generar esencia.
- Comprar mejoras.
- Guardar datos.

Salida:

```text
bucle de producción jugable
```

### Fase 2 — Colección y progresión

- Añadir 12 criaturas.
- Rarezas.
- Inventario.
- Bestiario.
- Duplicados.
- Evolución o fusión sencilla.
- Desbloqueo de hábitats.

Salida:

```text
motivo claro para seguir consiguiendo criaturas
```

### Fase 3 — Expedición

- Seleccionar criaturas.
- Enviar expedición.
- Resolver duración/recompensas.
- Añadir una zona.
- Añadir huevo o criatura rara.

Salida:

```text
actividad activa que rompe la espera
```

### Fase 4 — Defensa nocturna

- Ciclo día/noche.
- Enemigos.
- Oleadas.
- Guardianes.
- Daño al núcleo.
- Recompensa por sobrevivir.

Salida:

```text
la colección tiene función estratégica
```

### Fase 5 — Tutorial, móvil y pulido

- Tutorial de primera sesión.
- UI móvil.
- Feedback visual y sonoro.
- Errores controlados.
- Rendimiento.
- Nombres y textos claros.

Salida:

```text
MVP listo para prueba cerrada
```

### Fase 6 — Test cerrado

Probar con pocos jugadores reales.

Registrar:

- ¿Entienden el objetivo?
- Tiempo hasta primera criatura.
- Tiempo hasta primera mejora.
- ¿Usan expediciones?
- ¿Preparan defensa?
- ¿Vuelven al día siguiente?
- ¿Qué sistema ignoran?
- ¿Dónde abandonan?

No ampliar contenido antes de corregir los bloqueos principales.

### Fase 7 — Primera publicación

- Revisar nombres e identidad.
- Revisar derechos y assets.
- Quitar comandos de administración.
- Configurar IDs reales.
- Revisar guardado.
- Revisar móvil.
- Preparar icono, thumbnail y descripción.
- Publicar una versión pequeña.

### Fase 8 — Actualizaciones

Prioridad:

1. Corregir errores.
2. Mejorar el primer minuto.
3. Mejorar la retención inicial.
4. Añadir una nueva criatura o hábitat.
5. Añadir un evento solo si los jugadores siguen activos.

No añadir sistemas grandes por ansiedad si los jugadores no están usando los sistemas actuales.

### Fase 9 — Extracción del framework

Solo después de tener el primer juego funcional:

- Extraer servicios genéricos.
- Extraer definiciones configurables.
- Crear una plantilla de nuevo juego.
- Documentar comandos de generación.
- Crear un segundo incremental con otra temática.

La fábrica debe nacer de código repetido, no de especulación.

---

## 11. Pruebas y QA

### Pruebas técnicas

- Obtener criatura.
- Colocar criatura.
- Retirar criatura.
- Ganar esencia.
- Comprar mejora.
- Salir y volver a entrar.
- Recompensa de expedición.
- Evolución.
- Derrota nocturna.
- Victoria nocturna.
- Reconexión.
- Servidor lleno.
- Compra repetida.
- RemoteEvent con valores falsos.
- Cliente intentando reclamar recompensas.

### Pruebas de diseño

- ¿Se entiende el objetivo en 30 segundos?
- ¿Hay una decisión interesante en los primeros 5 minutos?
- ¿La producción se siente rápida al principio?
- ¿La defensa aporta tensión?
- ¿Hay una próxima meta visible?
- ¿Las rarezas importan sin hacer inútiles las criaturas comunes?
- ¿La interfaz funciona sin leer un manual?

### Pruebas de rendimiento

- Servidor con varios jugadores.
- Muchas criaturas colocadas.
- Oleadas con enemigos.
- Dispositivos móviles.
- Memoria y partes.
- Tiempo de carga.
- Errores en Output.

---

## 12. Métricas y decisiones

Registrar antes del test:

- Jugadores que empiezan.
- Jugadores que consiguen la primera criatura.
- Jugadores que hacen la primera mejora.
- Jugadores que entran a una expedición.
- Jugadores que sobreviven una noche.
- Duración de sesión.
- Retorno al día siguiente.
- Criaturas más usadas.
- Sistemas ignorados.
- Compras, si existen.

No decidir solo por visitas.

### Señales positivas

- Los jugadores entienden el loop sin ayuda.
- Quieren enseñar su colección.
- Comparan criaturas.
- Preguntan por próximas zonas.
- Vuelven sin que se les recuerde.
- Piden intercambios o cooperación.

### Señales negativas

- Solo esperan monedas.
- Ignoran expediciones y defensa.
- Abandonan antes de conseguir la primera mejora.
- No entienden por qué una criatura es mejor.
- La progresión se siente lenta o vacía.

### Criterios de decisión

Después del test elegir una de estas opciones:

```text
Continuar: el loop funciona y hay señales de retorno.
Iterar: hay interés, pero el onboarding o el ritmo fallan.
Pivotar: la colección interesa, pero la defensa/producción no.
Parar: no hay interés y arreglarlo exigiría rehacerlo todo.
```

---

## 13. Riesgos

### Riesgo técnico

El código vive principalmente en Roblox Studio. Antes de convertirlo en base reutilizable hay que exportarlo y versionarlo.

Mitigación:

- Rojo o exportación equivalente.
- Git desde el primer día.
- Copias del place.
- Commits pequeños.

### Riesgo de alcance

Añadir demasiados hábitats, criaturas, zonas y sistemas antes del test.

Mitigación:

- 12 criaturas y un mapa primero.
- Feature flags.
- No fabricar contenido para jugadores que todavía no existen.

### Riesgo de identidad

Parecer un reskin de Steal a Brainrot, Steal a Meme o un juego de criaturas existente.

Mitigación:

- Identidad visual propia.
- Terminología propia.
- Criaturas originales.
- Bucle de defensa y expediciones como núcleo.

### Riesgo de economía

Producción demasiado rápida o lenta; una criatura vuelve inútiles a todas las demás.

Mitigación:

- Simulador de economía en Lua o Python.
- Tabla de progresión.
- Pruebas con datos de ejemplo.
- No añadir demasiadas monedas.

### Riesgo de persistencia

Pérdida o duplicación de criaturas y recompensas.

Mitigación:

- Esquema versionado.
- Logs de guardado.
- Recompensas idempotentes.
- Pruebas de reconexión.

### Riesgo de plataforma

Cambios de descubrimiento, competencia o tendencias.

Mitigación:

- Coste pequeño de producción.
- Varios conceptos a lo largo del tiempo.
- Aprender de cada lanzamiento.
- No apostar todo a anuncios.

---

## 14. Ideas futuras

Estas ideas no pertenecen al MVP, pero pueden alimentar actualizaciones:

### Santuario corrupto

Una zona que produce más, pero aumenta el riesgo de oleadas.

### Expedición con decisiones

El jugador elige entre:

```text
ruta segura → recompensa normal
ruta peligrosa → criatura rara
ruta misteriosa → evento aleatorio
```

### Sinergias de hábitat

Combinar criaturas de bosque, agua, fuego o sombra para activar bonificaciones.

### Jefes de guarida

Los jugadores cooperan para derrotar una criatura grande y obtener una variante limitada.

### Temporadas

Cada temporada añade:

- 3–5 criaturas.
- 1 evento.
- 1 decoración.
- 1 objetivo comunitario.

### Pérdida controlada

Una criatura puede quedar herida y necesitar recuperación, pero no debe perderse de forma injusta.

### Visitas

Los jugadores pueden visitar otros santuarios y votar por diseños o colecciones.

### Mercado seguro

Solo cuando la economía sea estable. Usar intercambios server-side y confirmación doble.

### Variantes cosméticas

- Albina.
- Nocturna.
- Cristal.
- Corrupta.
- Estacional.

---

## 15. Tareas concretas para Claude

Cuando se empiece el desarrollo, usar este prompt:

```text
Lee todo el repositorio MAtt81245/Plans., especialmente:
- CURRENT_STATE.md
- PROJECT_CONTEXT.md
- docs/games/steal-a-meme-summary.txt
- docs/games/creature-sanctuary-plan.md
- docs/BLENDER_PIXEL_ART.md
- AI_INSTRUCTIONS.md
- CLAUDE.md

Quiero construir el MVP de Creature Sanctuary reutilizando de forma segura
partes de Steal a Meme y Forest Mode.

No programes todo de una vez.

Primero:
1. Haz un inventario de sistemas reutilizables.
2. Separa sistemas genéricos de lógica temática de memes.
3. Identifica qué está solo en Studio y necesita versionarse.
4. Propón una migración mínima y segura.
5. Define las interfaces entre PlayerData, Creature, Habitat, Income,
   Expedition, Defense y Upgrade.
6. Crea una lista de tareas ordenada para el MVP.
7. No borres ni sobrescribas el juego original.
8. Pide confirmación antes de editar Roblox Studio.

El MVP debe tener solo:
- 12 criaturas.
- 3 hábitats.
- 1 moneda.
- 1 expedición.
- 1 ciclo de defensa.
- 1 evolución o fusión.
- guardado y UI básica.

No añadas PvP, comercio, temporadas, 100 criaturas, múltiples mundos,
combate por turnos completo ni monetización compleja todavía.
```

---

## 16. Próxima acción exacta

No construir todavía la fábrica completa.

Primero:

```text
1. Crear una copia segura del juego.
2. Exportar y versionar el código de Steal a Meme.
3. Clasificar los módulos reutilizables.
4. Crear el nuevo place de prueba.
5. Implementar santuario + una criatura + producción + guardado.
6. Probar ese bucle con una persona real.
```

Si el primer bucle no resulta claro o divertido, no añadir expediciones, temporadas ni más criaturas.

---

## 17. Estado del plan

- Estado: concepto aprobado para investigación/prototipo.
- Dependencia: terminar o pausar con seguridad Rogue Tamer y decidir su primera prueba real.
- Prioridad: después de tener una versión jugable de Rogue Tamer, salvo que se decida cambiar antes.
- Próximo hito: vertical slice de Creature Sanctuary.
- No confundir este documento con evidencia de demanda. La demanda debe probarse con jugadores reales.
