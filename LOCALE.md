# Localización (ES / EN) — Investigación y plan

Documento de referencia para implementar **español latino** e **inglés** como idiomas seleccionables desde el menú de configuración. No es una guía de uso del juego; resume el estado actual del proyecto, la dificultad estimada y cómo abordarlo cuando decidamos hacerlo.

---

## Resumen ejecutivo

| Aspecto | Valoración |
|---------|------------|
| **Dificultad global** | Media (6/10) |
| **Selector de idioma en menú** | Baja — encaja con `Settings` existente |
| **Traducir todo el contenido** | Media–alta — trabajo de contenido + QA |
| **Tiempo estimado (demo completa bilingüe)** | 2–4 días de desarrollo + redacción EN |
| **Bloqueadores técnicos** | Ninguno grave; Dialogue Manager ya preparado |

La parte **rápida** es la infraestructura (guardar locale, `TranslationServer`, OptionButton). La parte **lenta** es localizar cada texto suelto del proyecto y escribir/revisar las traducciones.

---

## Estado actual del proyecto

### Lo que ya existe

| Pieza | Estado |
|-------|--------|
| `scripts/autoload/settings.gd` | Persiste preferencias en `user://settings.json` (FOV, volumen, perfil de movimiento, etc.) |
| `scenes/ui/config_module.tscn` | Menú de opciones reutilizable (main menu + pausa) |
| **Dialogue Manager** | Soporte nativo de traducciones CSV; export/import desde el editor |
| `scenes/dialogue/balloon.gd` | Escucha `NOTIFICATION_TRANSLATION_CHANGED` y refresca la línea activa al cambiar idioma |
| `project.godot` | **Sin** sección `[internationalization]` configurada aún |

### Lo que no está preparado

- Casi todo el texto visible está **hardcodeado** en español (escenas `.tscn`, scripts `.gd`, recursos `.tres`).
- No hay uso de `tr()` ni claves de traducción en UI propia del juego.
- La intro de `level_2` usa `resources/narrative/level_2_intro.tres` con párrafos embebidos.
- Prompts de interacción (`prompt_text` en componentes) están en las escenas, no en CSV.

---

## Inventario de textos a localizar

### 1. Menús y UI (~30–50 cadenas)

**Archivos principales:**

- `scenes/ui/config_module.tscn` — títulos: Configuration, Master Volume, Music Volume, SFX Volume, Fullscreen, Mouse sensitivity, FOV, Movement profile, Back
- `scenes/ui/pause_menu.tscn` — Resume, Options, Main Menu
- `scenes/main/main_menu.tscn` — botones del menú principal
- `scripts/ui/movement_profile_control.gd` — Production / Develop
- `scenes/ui/level_intro_overlay.tscn` — hint por defecto
- `scripts/narrative/level_intro_controller.gd` — fallback `"Clic para seguir leyendo"`
- `resources/narrative/level_2_intro.tres` — **12+ párrafos** de intro (2 secciones × 2 páginas)

### 2. Diálogos NPC (~6 archivos)

| Archivo | Uso |
|---------|-----|
| `dialogues/gas_station_npc.dialogue` | NPC gasolinera |
| `dialogues/door_01.dialogue` | Puertas |
| `dialogues/ice_proximity.dialogue` | Proximidad hielo |
| `dialogues/demo/clown_jumpscare_easter_egg.dialogue` | Easter egg payaso |
| `dialogues/my_dialogue.dialogue` | Pruebas / genérico |

Dialogue Manager permite mantener los mismos `~ start`, `~ repeat`, etc. y traducir el contenido vía CSV por locale.

### 3. Gameplay dinámico (scripts)

| Archivo | Ejemplos de texto |
|---------|-------------------|
| `scripts/dialogue/interactable_dialogue_component.gd` | `prompt_text` por defecto |
| `scripts/interactables/toilet_pee_setup.gd` | hints del minijuego, vejiga, prompts |
| `scenes/interactables/toilet_pee_setup.tscn` | labels de UI embebidos |
| `scripts/autoload/inner_thoughts.gd` | pensamientos (vía `show_thought()`) |
| `scripts/interactables/door_interact_setup.gd` | diálogos locked/unlocked |
| `scenes/characters/gas_station_npc/gas_station_npc.tscn` | `"Presiona [E] para hablar"` |

### 4. Sistemas narrativos

- `resources/narrative/gas_station_npc_dialogue.tres` — usa `dialogue_title` que apunta a bloques del `.dialogue` (se traduce con Dialogue Manager, no el `.tres` en sí).
- `resources/narrative/level_2_scenes.tres` — `display_name` solo referencia de diseño; baja prioridad.

---

## Arquitectura recomendada

### Capa 1 — Settings + aplicación de locale

Extender `settings.gd`:

```gdscript
const DEFAULT_LOCALE := "es"
const SUPPORTED_LOCALES := ["es", "en"]

func get_locale() -> String:
    return str(get_value("locale", DEFAULT_LOCALE))

func set_locale(locale: String) -> void:
    if locale not in SUPPORTED_LOCALES:
        return
    data["locale"] = locale
    apply_locale()

func apply_locale() -> void:
    TranslationServer.set_locale(get_locale())
    # Opcional: señal locale_changed para UI que no use tr() automático
```

En `_ready()` de `Settings`, llamar `apply_locale()` después de `load_settings()`.

**Control en UI:** nuevo `OptionButton` en `config_module.tscn`, script similar a `movement_profile_control.gd`:

- Español → `"es"`
- English → `"en"`

Al cambiar: `Settings.set_locale(...)`, `Settings.save_settings()`, refrescar textos si hace falta.

### Capa 2 — Traducciones de UI (Godot CSV)

Crear p. ej. `translations/ui.csv`:

```csv
keys,es,en
UI_CONFIG_TITLE,Configuración,Configuration
UI_MASTER_VOLUME,Volumen general,Master Volume
UI_CLICK_TO_CONTINUE,Clic para seguir leyendo,Click to continue reading
UI_PROMPT_TALK,Presiona [E] para hablar,Press [E] to talk
...
```

Registrar en **Project → Project Settings → Localization**:

- Añadir CSV como recurso de traducción.
- Locales: `es`, `en`.
- Locale por defecto: `es` (español latino).

**Uso en escenas:**

- Marcar nodos Label/Button como **Localize** (propiedad `auto_translate` / claves en el inspector), **o**
- En scripts: `label.text = tr("UI_CONFIG_TITLE")`.

**Uso en `.tscn`:** preferir claves en propiedad `text` con localización activada en el nodo, o setear desde script en `_ready()` con `tr()`.

### Capa 3 — Diálogos (Dialogue Manager)

Flujo estándar del addon:

1. Abrir un `.dialogue` en el editor de Dialogue Manager.
2. **Project → Export translations** (genera/actualiza CSV con claves por línea).
3. Añadir columna `en` (o archivo separado según configuración del plugin).
4. Traducir manteniendo keys y títulos (`~ start`, etc.).
5. Importar CSV al proyecto Godot.

El balloon del proyecto (`scenes/dialogue/balloon.gd`) ya reacciona al cambio de locale en mitad de conversación — ventaja importante.

**Nota:** decidir si las traducciones EN usan español latino neutro o inglés americano; conviene documentarlo en el CSV (glosario).

### Capa 4 — Intro del nivel 2

Dos enfoques viables:

| Enfoque | Pros | Contras |
|---------|------|---------|
| **A) Dos recursos** `level_2_intro.es.tres` + `level_2_intro.en.tres` | Rápido, sin tocar controller | Duplicar contenido al editar |
| **B) Claves + `tr()`** en `LevelIntroController` | Un solo flujo, mantenible | Refactor de `LevelIntroParagraph` / sequence |

Recomendación para **primera iteración:** enfoque A.  
Recomendación **a largo plazo:** enfoque B con claves tipo `INTRO_DEMO_P1`.

`LevelIntroSetup` elegiría el recurso según `Settings.get_locale()`.

### Capa 5 — Texto dinámico en runtime

Patrón único en el codebase:

```gdscript
_hint_label.text = tr("UI_CLICK_TO_CONTINUE")
InnerThoughts.show_thought(tr("THOUGHT_EMPTY_BLADDER"))
```

Para `@export var prompt_text` en componentes: asignar en `_ready()` desde clave, o usar placeholder en escena + script que llame `tr()`.

---

## Cambios en `project.godot` (cuando se implemente)

Ejemplo de sección a añadir:

```ini
[internationalization]

locale/translations=PackedStringArray("res://translations/ui.en.translation", "res://translations/ui.es.translation")
locale/fallback="es"
```

(Las rutas exactas dependen de cómo Godot importe el CSV; suele generar `.translation` binarios al importar.)

---

## Señales y refresco de UI

Al cambiar idioma **en pausa** conviene:

1. `TranslationServer.set_locale(new_locale)`
2. Emitir señal global (p. ej. `Settings.locale_changed`)
3. Menús abiertos: reconectar textos o usar nodos con auto-translate
4. **No** reiniciar nivel salvo que sea intro activa o diálogo complejo

Sistemas que ya reaccionan solos:

- Dialogue Manager balloon (cambio de locale mid-dialogue)

Sistemas que hay que refrescar manualmente:

- Intro si está en curso (raro)
- Labels seteados una sola vez en `_ready()` sin `tr()`
- `prompt_text` en interactables si se leyó antes del cambio

---

## Plan por fases (recomendado)

### Fase A — Infraestructura + menús (~1 día)

- [ ] `locale` en `settings.gd` + persistencia JSON
- [ ] OptionButton idioma en `config_module.tscn`
- [ ] CSV `translations/ui.csv` con menús (config, pausa, main)
- [ ] `[internationalization]` en `project.godot`
- [ ] Probar cambio ES ↔ EN desde menú principal y pausa

### Fase B — Diálogos (~1–2 días)

- [ ] Export CSV desde cada `.dialogue`
- [ ] Redactar traducciones EN (latinoamericano → inglés natural, no literal palabra por palabra)
- [ ] Probar cada NPC, puerta y easter egg en ambos idiomas

### Fase C — Gameplay y narrativa (~1 día)

- [ ] Intro `level_2` (recurso EN o claves)
- [ ] Prompts de interacción
- [ ] Minijuego baño (`toilet_pee_setup`)
- [ ] Pensamientos internos hardcodeados
- [ ] Pass de QA: level_2 completo en ES y EN

### Fase D — Pulido (opcional)

- [ ] Detectar locale del SO al primer arranque (`OS.get_locale()`)
- [ ] Icono/bandera en selector (cosmético)
- [ ] Reglas de estilo (tú vs you, [E] vs [E] en prompts)
- [ ] CI: aviso si falta clave EN en CSV

---

## Estimación de esfuerzo

| Tarea | Horas aprox. |
|-------|----------------|
| Settings + selector + project.godot | 2–4 |
| UI menús (CSV + escenas) | 4–6 |
| Diálogos (6 archivos, redacción EN) | 8–16 |
| Intro level_2 | 3–5 |
| Prompts / hints / pensamientos | 4–8 |
| QA y fixes | 4–8 |
| **Total demo bilingüe** | **25–47 h** |

---

## Riesgos y gotchas

1. **Texto en `.tscn` sin localizar** — fácil olvidar un Label; hacer checklist por escena.
2. **Intro `.tres`** — no pasa por Dialogue Manager; requiere estrategia propia (A o B arriba).
3. **`@export` strings** — valores por defecto en inspector no se traducen solos; override en `_ready()` con `tr()`.
4. **Español latino vs español de España** — el contenido actual ya está en latino; mantener criterio en futuras líneas ES.
5. **Cambio de idioma mid-game** — prompts ya mostrados no se actualizan hasta re-entrar en rango; aceptable para demo.
6. **Dialogue Manager CSV** — respetar keys al editar; no cambiar títulos `~ start` entre idiomas.
7. **Fuentes** — Jackwrite/Roboto soportan latin básico; verificar caracteres especiales en EN (poco problema).

---

## Convenciones sugeridas (si se implementa)

### Claves de traducción

```
UI_*           → menús e interfaz
PROMPT_*       → interacción (E, Q, etc.)
INTRO_*        → intro level_2
THOUGHT_*      → pensamientos internos
PEE_*          → minijuego baño
```

### Locales

| Código | Idioma |
|--------|--------|
| `es` | Español (latinoamericano) — **default** |
| `en` | English |

### Glosario demo (ejemplo)

| ES | EN sugerido |
|----|-------------|
| Presiona [E] para hablar | Press [E] to talk |
| Vejiga | Bladder |
| Clic para seguir leyendo | Click to continue reading |
| Gasolinera | Gas station |

---

## Archivos a tocar (checklist rápida)

```
scripts/autoload/settings.gd          ← locale get/set/apply
scripts/ui/locale_control.gd          ← nuevo (OptionButton)
scenes/ui/config_module.tscn          ← control idioma
project.godot                         ← internationalization
translations/ui.csv                   ← nuevo
translations/*.translation            ← generados por Godot

dialogues/*.dialogue                  ← export CSV EN
resources/narrative/level_2_intro.*   ← EN o claves

scripts/narrative/level_intro_setup.gd
scripts/narrative/level_intro_controller.gd
scripts/dialogue/interactable_dialogue_component.gd
scripts/interactables/toilet_pee_setup.gd
scenes/ui/pause_menu.tscn
scenes/main/main_menu.tscn
```

---

## Referencias en el repo

| Tema | Ruta |
|------|------|
| Settings persistidos | `scripts/autoload/settings.gd` |
| Menú opciones | `scenes/ui/config_module.tscn` |
| Perfil movimiento (patrón OptionButton) | `scripts/ui/movement_profile_control.gd` |
| Balloon + cambio locale | `scenes/dialogue/balloon.gd` (~L179) |
| Intro narrativa | `resources/narrative/level_2_intro.tres` |
| Escenas narrativas (otro doc) | `README.md` |

---

## Decisión pendiente

Cuando el equipo decida implementar:

1. Confirmar **Fase A** como MVP (menús + selector funcionando).
2. Elegir enfoque intro: **A** (dos `.tres`) vs **B** (claves).
3. Asignar redacción EN (no solo traducción automática).
4. Actualizar este doc marcando fases completadas.

---

*Documento generado a partir de revisión del codebase (Godot 4.4, Dialogue Manager, Settings JSON, level_2 intro). Actualizar al implementar.*
