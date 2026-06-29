# project-13-f

Documentación del sistema de **escenas narrativas** dentro de un nivel, gestionado por `GameManager`.

---

## Concepto

Un **nivel** (por ejemplo `level_2.tscn`) es una escena de Godot física: mapa, props, NPCs, etc.

Dentro de ese mismo nivel pueden existir varias **escenas narrativas** (momentos / actos del gameplay). No son escenas de Godot distintas; son un estado lógico que controla:

- Qué diálogo debe mostrar cada NPC al interactuar.
- Qué objetivos cuenta como completados en ese tramo de la historia.
- Cuándo avanzar al siguiente “momento” del nivel.

```
level_2 (escena Godot)
├── arrival              ← escena narrativa inicial
├── explore_gas_station  ← tras hablar con el NPC, explorar la estación
└── supernatural_hint  ← cuando empieza lo raro
```

---

## Archivos del sistema

| Ruta | Descripción |
|------|-------------|
| `scripts/autoload/game_manager.gd` | API principal: escenas, objetivos, resolución de diálogos |
| `scripts/narrative/level_scene_profile.gd` | Recurso: define las escenas narrativas de un nivel |
| `scripts/narrative/level_scene_definition.gd` | Una escena narrativa concreta (`scene_id`, objetivos conocidos) |
| `scripts/narrative/npc_dialogue_profile.gd` | Perfil de diálogo ordenado para un NPC |
| `scripts/narrative/npc_dialogue_beat.gd` | Un beat con condiciones y efectos al terminar |
| `scripts/narrative/dialogue_beat_resolver.gd` | Evalúa qué beat aplica |
| `scripts/narrative/level_narrative_setup.gd` | Nodo para inicializar el nivel al cargar |
| `scripts/narrative/narrative_objective_trigger.gd` | Marca objetivos desde señales o `_ready` |
| `resources/narrative/` | Perfiles `.tres` del nivel y NPCs |

---

## Configurar un nivel

### 1. Crear el perfil de escenas

En el editor: **Nuevo recurso → LevelSceneProfile**.

Ejemplo existente: `resources/narrative/level_2_scenes.tres`

- `level_id`: identificador del nivel (`"level_2"`).
- `initial_scene_id`: escena narrativa al empezar (`"arrival"`).
- `scenes`: lista de `LevelSceneDefinition` con `scene_id`, `display_name` y `objective_ids` (referencia de diseño; no se auto-completan).

### 2. Añadir `NarrativeSetup` en la escena del nivel

En `level_2.tscn` ya hay un nodo de ejemplo:

```
level_2
└── NarrativeSetup   (script: level_narrative_setup.gd)
    ├── level_id = "level_2"
    └── scene_profile = level_2_scenes.tres
```

Al cargar el nivel, se llama automáticamente a:

```gdscript
GameManager.begin_level("level_2", "arrival", scene_profile)
```

Esto resetea el progreso narrativo de esa sesión y pone la escena inicial.

---

## API de GameManager

### Escenas narrativas

```gdscript
# Consultar escena activa
var scene := GameManager.get_level_scene()  # ej. "explore_gas_station"

# Cambiar de momento narrativo
GameManager.set_level_scene("supernatural_hint")
```

`set_level_scene()` valida que el `scene_id` exista en el `LevelSceneProfile` registrado. Si no existe, muestra un warning y no cambia nada.

### Objetivos

Los objetivos se guardan **por escena narrativa** dentro del nivel activo.

```gdscript
# Completar en la escena actual
GameManager.complete_objective("visited_bathroom")

# Completar en una escena concreta
GameManager.complete_objective("found_supermarket_key", "explore_gas_station")

# Comprobar
GameManager.has_objective("visited_bathroom")
GameManager.has_objective("visited_bathroom", "explore_gas_station")

# Buscar en cualquier escena del nivel
GameManager.has_objective_in_level("found_supermarket_key")

# Listar completados en la escena actual (o en una concreta)
var done := GameManager.get_completed_objectives()
```

### Flags globales (compatibilidad)

El sistema antiguo sigue disponible para puertas, minijuegos, etc.:

```gdscript
GameManager.set_flag("gas_npc_intro_done", true)
GameManager.get_flag("gas_npc_intro_done")
```

Los beats de diálogo pueden exigir flags con `required_flags` y asignarlos con `set_flags_on_finish`.

### Señales

```gdscript
GameManager.level_started.connect(func(level_id): ...)
GameManager.level_scene_changed.connect(func(level_id, scene_id, previous): ...)
GameManager.objective_completed.connect(func(level_id, scene_id, objective_id): ...)
GameManager.dialogue_beat_played.connect(func(npc_id, beat_id): ...)
```

Útiles para activar eventos (luces, spawns, música) cuando cambia el momento narrativo.

---

## Diálogos de NPC según escena y progreso

### Perfil de diálogo (`NpcDialogueProfile`)

Cada NPC puede tener un perfil `.tres` con una lista **ordenada** de beats.

**Regla importante:** se evalúan de arriba a abajo; **gana el primer beat que cumpla todas sus condiciones**. Pon los beats más específicos primero y el fallback al final.

Ejemplo: `resources/narrative/gas_station_npc_dialogue.tres`

| Orden | Beat | Condiciones | Diálogo |
|-------|------|-------------|---------|
| 1 | `after_bathroom` | escena `explore_gas_station` + objetivo `visited_bathroom` | `after_bathroom` |
| 2 | `repeat` | escena `explore_gas_station` + flag `gas_npc_intro_done` | `repeat` |
| 3 | `intro` | (sin condiciones) | `start` |

Al terminar el beat `intro`:
- Se activa el flag `gas_npc_intro_done`.
- La escena narrativa pasa a `explore_gas_station`.

### Campos de un `NpcDialogueBeat`

| Campo | Uso |
|-------|-----|
| `beat_id` | Identificador interno (para `play_once`) |
| `dialogue_title` | Título `~` en el archivo `.dialogue` |
| `required_scene_id` | Escena narrativa requerida (vacío = cualquiera) |
| `required_objectives` | Todos deben estar completados |
| `required_objectives_scene_id` | Buscar objetivos en otra escena concreta |
| `required_objectives_any_scene` | El objetivo vale si está en cualquier escena del nivel |
| `forbidden_objectives` | Si alguno está completado, el beat no aplica |
| `required_flags` | Flags globales requeridos |
| `play_once` | No repetir este beat |
| `complete_objectives_on_finish` | Objetivos a marcar al cerrar el diálogo |
| `set_scene_on_finish` | Escena narrativa a la que avanzar |
| `set_flags_on_finish` | Flags a activar al cerrar |

### Conectar al NPC

En `InteractableDialogueComponent`:

- `dialogue_resource` → archivo `.dialogue`
- `dialogue_profile` → `NpcDialogueProfile`
- `npc_id` → identificador del NPC (ej. `"gas_station_npc"`)

Si `dialogue_profile` está asignado, al pulsar **E** se resuelve el título automáticamente. Si ningún beat coincide, se usa `fallback_title` del perfil.

El archivo `.dialogue` debe tener un bloque por cada título:

```
~ start
Old Man: ...
=> END

~ repeat
Old Man: ...
=> END
```

---

## Marcar objetivos desde el juego

### Opción A — Código GDScript

```gdscript
GameManager.complete_objective("visited_bathroom")
```

### Opción B — Nodo `NarrativeObjectiveTrigger`

Añade un nodo con el script `narrative_objective_trigger.gd`:

- `objective_id` → `"visited_bathroom"`
- `auto_complete_on_ready` → marcar al cargar (útil para pruebas)
- O conecta una señal externa a `trigger()`

### Opción C — Desde un diálogo (Dialogue Manager)

En el `.dialogue`:

```
~ start
Old Man: Vuelve cuando hayas mirado el baño.
do GameManager.complete_objective("gas_npc_warned")
=> END
```

También puedes cambiar escena desde diálogo:

```
do GameManager.set_level_scene("supernatural_hint")
```

---

## Flujo de ejemplo (level 2)

```
1. Carga level_2
   └── NarrativeSetup → begin_level → escena "arrival"

2. Jugador habla con GasStationNPC
   └── Beat "intro" → diálogo ~ start
   └── Al cerrar → flag gas_npc_intro_done + escena "explore_gas_station"

3. Jugador usa el baño
   └── complete_objective("visited_bathroom")

4. Jugador vuelve a hablar con el NPC (si trigger_once = false)
   └── Beat "after_bathroom" → diálogo ~ after_bathroom
```

---

## Buenas prácticas

1. **Nombres consistentes** — Usa `snake_case` para `scene_id` y `objective_id` (`explore_gas_station`, `visited_bathroom`).
2. **Orden de beats** — Más condiciones arriba, fallback abajo.
3. **Objetivos vs flags** — Preferir objetivos para progreso narrativo por escena; flags para sistemas globales (puertas, minijuegos).
4. **Documentar en el perfil** — `objective_ids` en `LevelSceneDefinition` sirve como lista de referencia para el equipo.
5. **`trigger_once`** — Si quieres diálogos repetibles según progreso, desactiva `trigger_once` en `InteractableDialogueComponent`.
6. **Un `NarrativeSetup` por nivel** — Siempre al inicio de la jerarquía del nivel para que el estado esté listo antes de que el jugador interactúe.

---

## Referencia rápida

```gdscript
# Inicio (normalmente automático vía LevelNarrativeSetup)
GameManager.begin_level("level_2", "arrival", scene_profile)

# Estado
GameManager.current_level_id   # "level_2"
GameManager.get_level_scene()  # "arrival"

# Progreso
GameManager.complete_objective("visited_bathroom")
GameManager.has_objective("visited_bathroom")
GameManager.set_level_scene("explore_gas_station")

# Diálogo (uso interno; el componente lo hace solo)
var title := GameManager.resolve_npc_dialogue_title(dialogue_profile, "gas_station_npc")
```
