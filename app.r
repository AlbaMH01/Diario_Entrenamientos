library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)
library(tidyr)
library(DBI)
library(RPostgres)
library(jsonlite)
library(shinyjs)
library(ggplot2)
library(patchwork)

# 1. Función para abrir la conexión
conectar_db <- function() {
  tryCatch({
    con <- dbConnect(
      Postgres(),
      host     = Sys.getenv("SUPABASE_HOST"),
      dbname   = Sys.getenv("SUPABASE_DB"),
      user     = Sys.getenv("SUPABASE_USER"),
      password = Sys.getenv("SUPABASE_PASSWORD"),
      port     = as.numeric(Sys.getenv("SUPABASE_PORT"))
    )
    print("¡CONEXIÓN EXITOSA!")
    return(con)
  }, error = function(e) {
    message("Error al conectar: ", e$message)
    return(NULL)
  })
}

# 2. Función para leer datos
leer_datos <- function(query) {
  con <- conectar_db()
  
  # Si la conexión falló, salimos
  if (is.null(con)) return(NULL)
  
  # Intentamos la consulta
  tryCatch({
    res <- dbGetQuery(con, query)
    dbDisconnect(con)
    return(res)
  }, error = function(e) {
    dbDisconnect(con)
    message("Error en la consulta: ", e$message)
    return(NULL)
  })
}

# 3. Función para escribir los datos
insertar_fila <- function(tabla, nueva_fila_df) {
  con <- conectar_db()
  
  if (is.null(con)) return(FALSE)
  
  tryCatch({
    # append = TRUE significa que añade los datos al final de la tabla
    dbWriteTable(con, tabla, nueva_fila_df, append = TRUE, row.names = FALSE)
    dbDisconnect(con)
    return(TRUE)
  }, error = function(e) {
    if (!is.null(con)) dbDisconnect(con)
    message("Error al insertar: ", e$message)
    return(FALSE)
  })
}

con <- conectar_db()

# Verificación rápida
if(!is.null(con)){
  print("✅ Objeto 'con' creado y listo para la App.")
} else {
  print("❌ El objeto 'con' no pudo ser creado. Revisa tus variables de entorno.")
}

# --- 1. CONEXIÓN ---
if (!exists("con") || !dbIsValid(con)) {
  tryCatch({ source("conexion.R", local = FALSE) }, error = function(e) { message("Error conexión") })
}

# --- 2. UI ---
ui <- dashboardPage(
  dashboardHeader(title = "Planificador de Entrenamiento"),
  dashboardSidebar(
    sidebarMenu(id = "tabs_menu", 
                menuItem("Planificador", tabName = "planificador", icon = icon("calendar-alt")),
                # ¡Aquí está el nuevo botón del menú!
                menuItem("Resultados Atletas", tabName = "resultados", icon = icon("clipboard-check")),
                menuItem("Perfil Atletas", tabName = "perfil", icon = icon("user-alt")),
                menuItem("Análisis Rendimiento", tabName = "analisis", icon = icon("chart-line"))
    )
  ), 
  dashboardBody(
    useShinyjs(),
    tags$head(
      tags$style(HTML("
        .table thead th { background-color: #2c3e50 !important; color: white !important; text-align: center !important; }
        .table td { border: 1px solid #ddd !important; min-width: 280px; vertical-align: middle; padding: 12px !important; background-color: white !important; }
        /* Evitar fondo azul al seleccionar */
        table.dataTable tbody td.selected { background-color: white !important; box-shadow: none !important; color: inherit !important; }
        table.dataTable tbody tr.selected { background-color: white !important; box-shadow: none !important; color: inherit !important; }
        
        .select-micro { width: 100%; border-radius: 4px; height: 32px; border: 1px solid #3c8dbc; margin-bottom: 5px; }
        .input-sesion { width: 100%; border: 1px solid #ccc; border-radius: 4px; padding: 4px; font-size: 12px; }
        .input-fecha { width: 100%; border: 1px solid #3c8dbc; border-radius: 4px; padding: 2px; font-size: 11px; margin-top: 2px; margin-bottom: 5px; }
        .sesion-container { background: #f9f9f9; padding: 8px; border-radius: 5px; border: 1px solid #eee; margin-bottom: 5px; position: relative; }
        .btn-config { background: none; border: none; color: #3c8dbc; cursor: pointer; float: right; font-size: 14px; padding: 0; z-index: 100;}
        .btn-add { color: white !important; background-color: #28a745 !important; border:none; padding: 5px 12px; border-radius: 3px; cursor: pointer; margin-top: 5px; font-weight: bold; }
        .btn-del { color: white !important; background-color: #dc3545 !important; border:none; padding: 5px 12px; border-radius: 3px; cursor: pointer; margin-top: 5px; margin-left: 5px; font-weight: bold; }
        .modal-lg { width: 95% !important; max-width: 1600px !important; }
        .modal-body { padding: 20px 40px !important; }
        ")),
      tags$script(HTML("
        $(document).off('click', '.btn-config-js').on('click', '.btn-config-js', function(e) {
          e.preventDefault();
          var sid = $(this).attr('data-sid');
          Shiny.setInputValue('abrir_modal_js', sid, {priority: 'event'});
        });
        $(document).on('change', '.input-sesion, .input-fecha, .select-micro', function() {
          var id_ref = $(this).attr('id').split('_')[1]; 
          var campo = $(this).attr('id').split('_')[0]; 
          Shiny.setInputValue('cambio_vivo', { temp_id: id_ref, campo: campo, valor: $(this).val() }, {priority: 'event'});
        });
        $(document).on('click', '.btn-add-js', function(e) {
          e.preventDefault();
          Shiny.setInputValue('add_micro_js', $(this).data('meso'), {priority: 'event'});
        });
        $(document).on('click', '.btn-del-js', function(e) {
          e.preventDefault();
          Shiny.setInputValue('del_micro_js', {mid: $(this).data('meso'), tid: $(this).data('temp')}, {priority: 'event'});
        });
      "))
    ),
    tabItems(
      tabItem(tabName = "planificador",
        fluidRow(
          column(12,
            box(title = "Gestión de Temporada", width = 12, status = "primary", solidHeader = TRUE, 
                fluidRow(
                  column(3, textInput("año_escrito", "Temporada (Año):", value = "2026")),
                  column(3, uiOutput("selector_grupo_dinamico")),
                  column(6, style="margin-top: 25px;",
                    actionButton("btn_cargar_plan", "Cargar", icon = icon("download"), class="btn-info"),
                    actionButton("btn_abrir_modal_nuevo", "Nueva Temp.", icon = icon("plus"), class="btn-default"),
                    actionButton("btn_guardar_smart", "Sincronizar", icon = icon("save"), class="btn-success")
                  )
                )
            ),
            uiOutput("render_trimestres")
          )
        )
      ),
      
      # ==========================================
      # --- NUEVA PESTAÑA: RESULTADOS ---
      # ==========================================
      tabItem(tabName = "resultados",
        fluidRow(
          # Columna Izquierda: Selectores y Resumen del Plan
          column(4,
            box(title = "Selección de Entrenamiento", width = 12, status = "primary", solidHeader = TRUE,
                uiOutput("selector_atleta_resultados"),
                uiOutput("ui_selector_sesion")
            ),
            uiOutput("info_entreno_limpia")
          ),
          
          # Columna Derecha: Formulario de Resultados Dinámicos
          column(8,
            box(title = "Resultados de la Sesión", width = 12, status = "primary", solidHeader = TRUE,
                uiOutput("dinamico_series_resultados"),
                uiOutput("boton_guardar_resultados")
            )
          )
        )
      ),
      # --- PESTAÑA: PERFIL DEL ATLETA ---
      tabItem(tabName = "perfil",
              fluidRow(
                # Columna Izquierda: Selección
                column(4,
                       box(title = "Selección de Atleta", status = "primary", solidHeader = TRUE, width = NULL,
                           selectInput("perfil_grupo", "Selecciona Grupo:", choices = NULL),
                           selectInput("perfil_atleta_sel", "Selecciona Atleta:", choices = NULL)
                       )
                ),
                # Columna Derecha: Ficha de edición
                column(8,
                       box(title = "Datos", status = "primary", solidHeader = TRUE, width = NULL,
                           textInput("perfil_nombre", "Nombre del Atleta:", placeholder = "Ej: Kipchoge"),
                           
                           fluidRow(
                             column(6, numericInput("perfil_marca", "MMP (Prueba Principal):", value = NA, step = 0.1)),
                             column(6, numericInput("perfil_referencia", 'Ritmo Referencia / "/100m (seg):', value = NA, step = 0.1))
                           ),
                           
                           textAreaInput("perfil_comentarios", "Comentarios / Perfil Fisiológico:", rows = 4, placeholder = "Notas sobre su forma física..."),
                           
                           hr(),
                           fluidRow(
                             column(12, align = "right",
                                    actionButton("btn_guardar_perfil", "Actualizar Perfil", icon = icon("save"), class = "btn-success btn-lg")
                             )
                           )
                       )
                )
              )
      ),
    # ==========================================
    # --- UI: ANÁLISIS DE RENDIMIENTO ---
    # ==========================================
    tabItem(tabName = "analisis",
      
      # 1. FILTROS GENERALES ARRIBA (Tal cual tu boceto)
      fluidRow(
        box(title = "Filtros de Análisis", width = 12, status = "primary", solidHeader = TRUE,
          column(3, selectInput("ana_temporada", "1. Temporada (Año):", choices = NULL)), 
          column(3, selectInput("ana_grupo", "2. Grupo Entrenamiento:", choices = NULL)),
          column(3, selectInput("ana_macro", "3. Trimestre (Macro):", choices = NULL)),
          column(3, selectInput("ana_sesion", "4. Sesión (Fecha):", choices = NULL))
        )
      ),
      
      # 2. MENÚ DE TIPO DE GRÁFICA (El menú horizontal de tu dibujo)
      fluidRow(
        column(12,
          tabsetPanel(id = "menu_graficas", type = "pills",
            tabPanel("Gráfica Anual", value = "anual"),
            tabPanel("Gráfica Macrociclo", value = "macro"),
            tabPanel("Gráfica Sesión", value = "sesion"),
            tabPanel("Gráfica Timeline", value = "timeline")
          )
        )
      ),
      
      br(), # Un pequeño salto de línea para separar el menú de las gráficas
      
      # 3. CAJA: GRÁFICA GENERAL (Ocupa todo el ancho)
      fluidRow(
        column(12,
          box(title = "Gráfica General (Planificación Teórica)", width = 12, status = "info", solidHeader = TRUE,
              
              # Aquí Shiny muestra mágicamente solo la gráfica que hayas elegido en el menú
              conditionalPanel("input.menu_graficas == 'anual'", plotOutput("grafica_anual", height = "400px")),
              conditionalPanel("input.menu_graficas == 'macro'", plotOutput("grafica_macro", height = "400px")),
              conditionalPanel("input.menu_graficas == 'sesion'", plotOutput("grafica_sesion", height = "400px")),
              conditionalPanel("input.menu_graficas == 'timeline'", plotOutput("grafica_timeline_teoria", height = "400px"))
          )
        )
      ),
      
      # 4. CAJA: GRÁFICA ATLETA (Ocupa todo el ancho y lleva el filtro dentro)
      fluidRow(
                column(12, align = "right",
                  div(style = "display: flex; justify-content: flex-end; align-items: center; margin-bottom: 15px;",
                      
                      # 1. El icono suelto y centrado verticalmente
                      div(icon("user-alt"), style = "font-size: 20px; color: #d35400; margin-right: 10px;"),
                      
                      # 2. El recuadro del filtro sin texto arriba (label = NULL)
                      div(style = "width: 250px; text-align: left; margin-bottom: -15px;",
                          selectInput("ana_atleta", label = NULL, choices = NULL, width = "100%")
                      )
                  )
                )
              ),
              
              # Las gráficas del atleta, vinculadas al mismo menú
              conditionalPanel("input.menu_graficas == 'anual'", plotOutput("grafica_anual_atleta", height = "400px")),
              conditionalPanel("input.menu_graficas == 'macro'", plotOutput("grafica_macro_atleta", height = "400px")),
              conditionalPanel("input.menu_graficas == 'sesion'", plotOutput("grafica_sesion_atleta", height = "400px")),
              conditionalPanel("input.menu_graficas == 'timeline'", plotOutput("grafica_timeline_atleta", height = "400px"))
          )
        )
      )
    )

# --- 3. SERVIDOR ---
server <- function(input, output, session) {
  
  plan_borrador <- reactiveVal(NULL)
  refresh_trigger <- reactiveVal(rnorm(1))
  detalles_sesiones <- reactiveVal(list())
  sesion_actual_id <- reactiveVal(NULL)

  output$selector_grupo_dinamico <- renderUI({
    res <- dbGetQuery(con, "SELECT grupo_id, nombre_grupo FROM grupos_entrenamiento")
    selectInput("grupo_activo", "Grupo:", setNames(res$grupo_id, res$nombre_grupo))
  })

  # --- NUEVA TEMPORADA (Solo crea la estructura) ---
  observeEvent(input$btn_abrir_modal_nuevo, {
    req(input$año_escrito)
    showModal(modalDialog(
      title = "Crear Nueva Temporada",
      p(sprintf("Se va a crear la estructura de 4 Trimestres para el año %s y el grupo seleccionado.", input$año_escrito)),
      footer = tagList(
        modalButton("Cancelar"),
        actionButton("confirmar_creacion_db", "Crear en Base de Datos", class="btn-success")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$confirmar_creacion_db, {
    req(input$año_escrito, input$grupo_activo)
    año_txt <- trimws(input$año_escrito)
    g_id <- as.numeric(input$grupo_activo)
    
    tryCatch({
      dbBegin(con)
      # ¿Existe el año?
      res_a <- dbGetQuery(con, "SELECT año_id FROM años WHERE nombre_año = $1", list(año_txt))
      if(nrow(res_a) == 0) {
        a_id <- dbGetQuery(con, "INSERT INTO años (nombre_año) VALUES ($1) RETURNING año_id", list(año_txt))$año_id[1]
      } else { a_id <- res_a$año_id[1] }
      
      # ¿Existe la estructura?
      check_struct <- dbGetQuery(con, sprintf("SELECT macro_id FROM macrociclo WHERE año_id = %s AND grupo_id = %s", a_id, g_id))
      if(nrow(check_struct) == 0) {
        for(i in 1:4) {
          mid <- dbGetQuery(con, "INSERT INTO macrociclo (año_id, grupo_id, nombre_macro) VALUES ($1, $2, $3) RETURNING macro_id", 
                             list(as.numeric(a_id), as.numeric(g_id), paste("Trimestre", i)))$macro_id[1]
          for(n in c("Básico", "Específico", "Competición")) {
            dbExecute(con, "INSERT INTO mesociclo (macro_id, nombre_meso) VALUES ($1, $2)", list(as.numeric(mid), n))
          }
        }
        showNotification(paste("Temporada", año_txt, "creada. Ahora pulsa 'Cargar'."), type="message")
      } else {
        showNotification("Este grupo ya tiene una estructura creada en este año.", type="warning")
      }
      dbCommit(con)
      removeModal()
    }, error = function(e) {
      if(dbIsValid(con)) dbRollback(con)
      removeModal()
      showNotification(paste("Error:", e$message), type="error")
    })
  })


  # --- CARGAR (A prueba de nulos y leyendo Métricas Generales) ---
  observeEvent(input$btn_cargar_plan, {
    req(input$año_escrito, input$grupo_activo)
    año_txt <- trimws(input$año_escrito)
    g_id <- as.numeric(input$grupo_activo)
    
    showModal(modalDialog("Cargando y verificando estructura...", footer=NULL))
    
    tryCatch({
      # 1. Verificar Año
      res_a <- dbGetQuery(con, "SELECT año_id FROM años WHERE nombre_año = $1", list(año_txt))
      if(nrow(res_a) == 0) {
        removeModal()
        showNotification("Este año no existe. Pulsa 'Nueva Temp.'", type="warning")
        return()
      }
      a_id <- res_a$año_id[1]
      
      # 2. Verificar Macros (Trimestres)
      macros <- dbGetQuery(con, sprintf("SELECT macro_id FROM macrociclo WHERE año_id = %s AND grupo_id = %s", a_id, g_id))
      if(nrow(macros) == 0) {
        removeModal()
        showNotification("No hay estructura para este año/grupo. Pulsa 'Nueva Temp.'", type="warning")
        return()
      }
      
      # 3. AUTO-REPARACIÓN: Verificar si esos macros tienen mesociclos
      m_ids_check <- paste(macros$macro_id, collapse = ",")
      mesos_count <- dbGetQuery(con, sprintf("SELECT COUNT(*) as n FROM mesociclo WHERE macro_id IN (%s)", m_ids_check))
      
      if(mesos_count$n == 0) {
        showNotification("Estructura incompleta detectada. Auto-reparando...", type="warning")
        dbBegin(con)
        for(m_id in macros$macro_id) {
          for(n in c("Básico", "Específico", "Competición")) {
            dbExecute(con, "INSERT INTO mesociclo (macro_id, nombre_meso) VALUES ($1, $2)", list(as.numeric(m_id), n))
          }
        }
        dbCommit(con)
      }

      # 4. Cargar base de la estructura
      base <- dbGetQuery(con, sprintf("
        SELECT ma.macro_id, ms.nombre_meso, ms.meso_id 
        FROM macrociclo ma JOIN mesociclo ms ON ms.macro_id = ma.macro_id 
        WHERE ma.grupo_id = %s AND ma.año_id = %s", g_id, a_id)) %>%
        mutate(orden = case_when(grepl("Bás", nombre_meso)~1, grepl("Esp", nombre_meso)~2, TRUE~3)) %>%
        arrange(macro_id, orden) %>% mutate(temp_id = row_number(), f1="", s1="", f2="", s2="", tipo_micro="", e1="", e2="")

      # 5. Cargar datos (¡AHORA LEYENDO METRICAS_GENERALES TAMBIÉN!)
      ids_mesos <- paste(base$meso_id[!is.na(base$meso_id)], collapse = ",")
      if(ids_mesos != "") {
        query_d <- sprintf("SELECT mi.meso_id, mi.micro_id, mi.tipo_micro::text, s.fecha::text, s.objetivo_sesion, s.estructura::text, s.metricas_generales::text, s.comentarios 
                            FROM microciclo mi LEFT JOIN sesion s ON mi.micro_id = s.micro_id AND s.grupo_id = %s
                            WHERE mi.meso_id IN (%s)", g_id, ids_mesos)
        datos <- dbGetQuery(con, query_d)
      } else {
        datos <- data.frame(micro_id = NA)
      }
      
      # 6. Procesar y montar el borrador
      if(nrow(datos) > 0 && !all(is.na(datos$micro_id))) {
        plan_proc <- datos %>% filter(!is.na(micro_id)) %>%
          group_by(meso_id, micro_id, tipo_micro) %>%
          summarise(
            f1 = first(fecha), s1 = first(objetivo_sesion), e1 = first(estructura), m1 = first(metricas_generales), c1 = first(comentarios),
            f2 = if(n()>=2) nth(fecha,2) else "", 
            s2 = if(n()>=2) nth(objetivo_sesion,2) else "", 
            e2 = if(n()>=2) nth(estructura,2) else "", 
            m2 = if(n()>=2) nth(metricas_generales,2) else "",
            c2 = if(n()>=2) nth(comentarios,2) else "", 
            .groups='drop'
          ) %>%
          right_join(base %>% select(meso_id, nombre_meso, macro_id, orden), by="meso_id") %>%
          arrange(macro_id, orden, micro_id) %>% mutate(temp_id = row_number()) %>%
          mutate(across(c(f1, s1, e1, m1, c1, f2, s2, e2, m2, c2, tipo_micro), ~coalesce(as.character(.), "")))

        nuevos_det <- list()
        for(i in 1:nrow(plan_proc)) {
          # SESIÓN 1
          if(!is.na(plan_proc$e1[i]) && plan_proc$e1[i] != "") { 
            d1 <- fromJSON(plan_proc$e1[i])
            # Fusionar con métricas si existen
            if(!is.na(plan_proc$m1[i]) && plan_proc$m1[i] != "") {
              met1 <- fromJSON(plan_proc$m1[i])
              d1 <- c(d1, met1)
            }
            d1$obs <- plan_proc$c1[i]
            nuevos_det[[paste0("s1_t", plan_proc$temp_id[i])]] <- d1 
          }
          # SESIÓN 2
          if(!is.na(plan_proc$e2[i]) && plan_proc$e2[i] != "") { 
            d2 <- fromJSON(plan_proc$e2[i])
            # Fusionar con métricas si existen
            if(!is.na(plan_proc$m2[i]) && plan_proc$m2[i] != "") {
              met2 <- fromJSON(plan_proc$m2[i])
              d2 <- c(d2, met2)
            }
            d2$obs <- plan_proc$c2[i]
            nuevos_det[[paste0("s2_t", plan_proc$temp_id[i])]] <- d2 
          }
        }
        plan_borrador(plan_proc); detalles_sesiones(nuevos_det)
      } else {
        plan_borrador(base); detalles_sesiones(list())
      }
      removeModal(); refresh_trigger(rnorm(1))
    }, error = function(e) { 
      removeModal()
      showNotification(paste("Error en carga:", e$message), type="error", duration = 10) 
    })
  })


  # --- AÑADIR MICRO (Por posición física) ---
  observeEvent(input$add_micro_js, {
    curr <- plan_borrador(); req(curr)
    target_meso <- as.numeric(input$add_micro_js)
    
    filas_meso <- which(as.numeric(curr$meso_id) == target_meso)
    if(length(filas_meso) == 0) return()
    
    pos_insercion <- max(filas_meso)
    
    clon <- curr[pos_insercion, ] %>% 
            mutate(micro_id=NA, f1="", s1="", f2="", s2="", tipo_micro="", 
                   temp_id = max(as.numeric(curr$temp_id), na.rm=T) + 1, e1="", e2="")
    
    if(pos_insercion == nrow(curr)) {
      nuevo_plan <- bind_rows(curr, clon)
    } else {
      nuevo_plan <- bind_rows(curr[1:pos_insercion, ], clon, curr[(pos_insercion+1):nrow(curr), ])
    }
    plan_borrador(nuevo_plan); refresh_trigger(rnorm(1))
  })

  # --- BORRAR MICRO (Asegurando numéricos para el filtro) ---
  observeEvent(input$del_micro_js, {
    curr <- plan_borrador(); req(curr)
    
    mid_target <- as.numeric(input$del_micro_js$mid)
    tid_target <- as.numeric(input$del_micro_js$tid)
    
    if(sum(as.numeric(curr$meso_id) == mid_target) > 1) { 
      nuevo_plan <- curr %>% filter(as.numeric(temp_id) != tid_target)
      plan_borrador(nuevo_plan)
      refresh_trigger(rnorm(1)) 
    } else {
      showNotification("Debe quedar al menos un microciclo.", type="warning")
    }
  })

  # --- EVENTOS EN VIVO (Mapeo corregido) ---
  observeEvent(input$cambio_vivo, {
    curr <- plan_borrador()
    info <- input$cambio_vivo
    
    idx <- which(as.numeric(curr$temp_id) == as.numeric(info$temp_id))
    if(length(idx) > 0) { 
      # Si el campo modificado es "sel", actualizamos "tipo_micro"
      campo_real <- if(info$campo == "sel") "tipo_micro" else info$campo
      
      curr[idx, campo_real] <- info$valor
      plan_borrador(curr) 
    }
  })

  # --- MODAL DETALLES (IDÉNTICO A TU DISEÑO VISUAL) ---
  observeEvent(input$abrir_modal_js, {
    id_ref <- input$abrir_modal_js
    sesion_actual_id(id_ref)
    datos <- detalles_sesiones()[[id_ref]]
    
    showModal(modalDialog(
      title = "Diseño Detallado de la Sesión", size = "l", 
      fluidRow(
        column(4, style = "border-right: 1px solid #eee;", 
          h4(icon("fire"), " Calentamiento"), 
          textAreaInput("m_calentamiento", "Descripción:", value = datos$calentamiento %||% "", height = "260px")
        ),
        column(4, style = "border-right: 1px solid #eee;", 
          h4(icon("bolt"), " Velocidad"),
          textAreaInput("m_vel_desc", "Estructura:", value = datos$vel_desc %||% "", height = "60px"),
          fluidRow(
            column(6, numericInput("m_vel_reps", "Reps:", value = datos$vel_reps %||% 1, min = 1)),
            column(6, textInput("m_vel_ritmo", "Ritmo:", value = datos$vel_ritmo %||% ""))
          ),
          textInput("m_vel_dist", "Distancias (m):", value = datos$vel_dist %||% "", placeholder="Ej: 30, 30, 30"),
          fluidRow(
            column(4, textInput("m_vel_rec_s", "Rec.S:", value = datos$vel_rec_s %||% "")),
            column(4, textInput("m_vel_rec_b", "Rec.B:", value = datos$vel_rec_b %||% "")),
            column(4, textInput("m_vel_densidad", "Dens. (1:X):", value = datos$vel_densidad %||% ""))
          )
        ),
        column(4, 
          h4(icon("running"), " Parte Principal"),
          textAreaInput("m_prin_desc", "Estructura:", value = datos$prin_desc %||% "", height = "60px"),
          fluidRow(
            column(6, numericInput("m_prin_reps", "Reps:", value = datos$prin_reps %||% 1, min = 1)),
            column(6, textInput("m_prin_ritmo", "Ritmo:", value = datos$prin_ritmo %||% ""))
          ),
          textInput("m_prin_dist", "Distancias (m):", value = datos$prin_dist %||% "", placeholder="Ej: 300, 400"),
          fluidRow(
            column(4, textInput("m_prin_rec_s", "Rec.S:", value = datos$prin_rec_s %||% "")),
            column(4, textInput("m_prin_rec_b", "Rec.B:", value = datos$prin_rec_b %||% "")),
            column(4, textInput("m_prin_densidad", "Dens. (1:X):", value = datos$prin_densidad %||% ""))
          )
        )
      ),
      footer = tagList(modalButton("Cancelar"), actionButton("confirmar_detalle", "Guardar Diseño", class="btn-success")), easyClose = TRUE
    ))
  })

  # --- GUARDAR EL DISEÑO DEL ENGRANAJE (Limpio y actualizado a la nueva foto) ---
  observeEvent(input$confirmar_detalle, {
    req(sesion_actual_id())
    lista <- detalles_sesiones()
    
    # Rellenamos la lista SOLO con lo que hay en el nuevo diseño visual
    lista[[sesion_actual_id()]] <- list(
      calentamiento = input$m_calentamiento %||% "",
      
      # Bloque Velocidad
      vel_desc     = input$m_vel_desc %||% "", 
      vel_reps     = input$m_vel_reps %||% 1, 
      vel_ritmo    = input$m_vel_ritmo %||% "", 
      vel_dist     = input$m_vel_dist %||% "",    # <-- La nueva casilla de distancias
      vel_rec_s    = input$m_vel_rec_s %||% "", 
      vel_rec_b    = input$m_vel_rec_b %||% "",
      vel_densidad = input$m_vel_densidad %||% "", # <-- La nueva casilla de densidad
      
      # Bloque Principal
      prin_desc     = input$m_prin_desc %||% "", 
      prin_reps     = input$m_prin_reps %||% 1, 
      prin_ritmo    = input$m_prin_ritmo %||% "", 
      prin_dist     = input$m_prin_dist %||% "",  # <-- La nueva casilla de distancias
      prin_rec_s    = input$m_prin_rec_s %||% "", 
      prin_rec_b    = input$m_prin_rec_b %||% "",
      prin_densidad = input$m_prin_densidad %||% "" # <-- La nueva casilla de densidad
    )
    
    detalles_sesiones(lista)
    removeModal()
  })

  # --- SINCRONIZAR (Definitivo con chaleco antibalas y Multi-Intensidad) ---
  # --- SINCRONIZAR (Definitivo, Indestructible y Exacto) ---
  observeEvent(input$btn_guardar_smart, {
    req(plan_borrador(), input$grupo_activo)
    data_final <- plan_borrador(); detalles <- detalles_sesiones(); g_id <- as.numeric(input$grupo_activo)
    showModal(modalDialog("Calculando cargas exactas por serie...", footer=NULL))
    
    # 0. Blindaje Extremo de la prueba objetivo
    res_p <- tryCatch(dbGetQuery(con, sprintf("SELECT pruebas FROM grupos_entrenamiento WHERE grupo_id = %s", g_id)), error=function(e) data.frame())
    
    prueba_m <- 1000
    if (isTRUE(nrow(res_p) > 0) && isTRUE(length(res_p$pruebas) > 0)) {
      val_p <- suppressWarnings(as.numeric(unlist(res_p$pruebas)[1]))
      if (!isTRUE(is.na(val_p)) && isTRUE(val_p > 0)) prueba_m <- val_p
    }

    # 1. TRADUCTOR BASE (100% Blindado)
    traducir_ritmo <- function(via_metabolica, prueba_ref, ritmo_txt) {
      if(is.null(ritmo_txt) || isTRUE(length(ritmo_txt) == 0) || isTRUE(is.na(unlist(ritmo_txt)[1])) || isTRUE(as.character(unlist(ritmo_txt)[1]) == "")) return(NA)
      
      r_clean <- gsub("[ \"']", "", tolower(as.character(unlist(ritmo_txt)[1])))
      if(isTRUE(r_clean %in% c("atope", "max", "máx", "100", "100%"))) r_clean <- "100%"
      if(isTRUE(grepl("ritmo(1000|800|2000)", r_clean))) r_clean <- "0"
      
      dict <- data.frame(
        shiny = c(9.0, 8.0, 7.2, 7.1, 6.3, 6.2, 6.1, 5.5, 5.4, 5.3, 5.2, 5.1, 4.5, 4.4, 4.3, 4.2, 4.1, 3.3, 3.2, 3.1, 2.2, 2.1, 1.0),
        ref_1000 = c("100%", "100%", "-5/95%", "-4/90%", "-3", "-2", "-1", "0", "+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9", "ritmo4000", "ritmo5000", "ritmo6000", "ritmo8000", "ritmo10000", "+ritmo10000"),
        ref_800  = c("100%", "100%", "-4/95%", "-3/90%", "-2", "-1", "0", "+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9", "+10", "ritmo4000", "ritmo5000", "ritmo6000", "ritmo8000", "ritmo10000", "+ritmo10000"),
        ref_2000 = c("100%", "100%", "-10/95%", "-9/90%", "-8", "-7", "-6", "-5", "-4", "-3", "-2", "-1", "0", "+1", "+2", "+3", "+4", "ritmo4000", "ritmo5000", "ritmo6000", "ritmo8000", "ritmo10000", "+ritmo10000"),
        stringsAsFactors = FALSE
      )
      
      col_buscar <- "ref_1000"
      if(!isTRUE(is.na(prueba_ref))) {
        if(isTRUE(prueba_ref == 800)) col_buscar <- "ref_800"
        if(isTRUE(prueba_ref == 2000)) col_buscar <- "ref_2000"
      }
      
      r_cmp <- gsub("\\+", "", r_clean)
      
      for(j in 1:nrow(dict)) {
        opts <- gsub("[ \"']", "", tolower(unlist(strsplit(dict[[col_buscar]][j], "/"))))
        opts_sin_mas <- gsub("\\+", "", opts)
        if(isTRUE(r_cmp %in% opts_sin_mas) || isTRUE(r_clean %in% opts)) return(dict$shiny[j])
      }
      return(NA) 
    }

    tryCatch({
      dbBegin(con)
      for(i in 1:nrow(data_final)) {
        for(s in 1:2) {
          fec <- if(isTRUE(s==1)) data_final$f1[i] else data_final$f2[i]
          obj <- if(isTRUE(s==1)) data_final$s1[i] else data_final$s2[i]
          
          # Chaleco antibalas total para el bucle
          fec_val <- unlist(fec)[1]
          obj_val <- unlist(obj)[1]
          
          if(!is.null(fec_val) && !is.null(obj_val) && !isTRUE(is.na(fec_val)) && !isTRUE(is.na(obj_val)) && isTRUE(as.character(fec_val) != "") && isTRUE(as.character(obj_val) != "")) {
            
            id_k <- paste0("s", s, "_t", data_final$temp_id[i])
            info <- detalles[[id_k]]
            if(is.null(info)) info <- list()

            # 2. PROCESAR VOLÚMENES
            calc_v <- function(d, r, p) {
              val_d <- unlist(d)[1]
              if(is.null(val_d) || isTRUE(is.na(val_d)) || isTRUE(as.character(val_d) == "")) return(list(t=0, vec=c(), str=""))
              
              ds <- suppressWarnings(as.numeric(unlist(strsplit(gsub("[^0-9,.]", "", as.character(val_d)), ","))))
              ds <- ds[!is.na(ds)]
              if(isTRUE(length(ds) == 0)) return(list(t=0, vec=c(), str=""))
              
              reps_val <- suppressWarnings(as.numeric(unlist(r)[1]))
              reps <- if (is.null(reps_val) || isTRUE(is.na(reps_val)) || isTRUE(reps_val < 1)) 1 else reps_val
              if (isTRUE(length(ds) == 1) && isTRUE(reps > 1)) ds <- rep(ds, reps)
              
              vec_v <- round(ds/p, 3)
              return(list(t = sum(vec_v), vec = vec_v, str = paste(vec_v, collapse=" | ")))
            }

            # 3. PROCESAR INTENSIDADES
            calc_i <- function(vias, p_ref, r_txt, num_reps) {
              val_r <- unlist(r_txt)[1]
              if(is.null(val_r) || isTRUE(is.na(val_r)) || isTRUE(as.character(val_r) == "")) return(list(vec=c(), str=""))
              
              ritmos <- trimws(unlist(strsplit(as.character(val_r), ",")))
              ritmos <- ritmos[ritmos != ""]
              if(isTRUE(length(ritmos) == 0)) return(list(vec=c(), str=""))
              
              reps_val <- suppressWarnings(as.numeric(unlist(num_reps)[1]))
              reps <- if (is.null(reps_val) || isTRUE(is.na(reps_val)) || isTRUE(reps_val < 1)) 1 else reps_val
              if(isTRUE(length(ritmos) == 1) && isTRUE(reps > 1)) ritmos <- rep(ritmos, reps)
              
              int_nums <- sapply(ritmos, function(rx) {
                vals <- sapply(vias, function(v) traducir_ritmo(v, p_ref, rx))
                vals <- vals[!is.na(vals)]
                if(isTRUE(length(vals) == 0)) return(0)
                return(mean(vals))
              })
              
              vec_i <- round(int_nums, 2)
              return(list(vec = vec_i, str = paste(vec_i, collapse=" | ")))
            }

            # 4. PROCESAR DENSIDADES
            calc_d <- function(d_txt, num_reps) {
              val_d <- unlist(d_txt)[1]
              if(is.null(val_d) || isTRUE(is.na(val_d)) || isTRUE(as.character(val_d) == "")) return(list(vec=c(), str="", media=0))
              
              d_arr <- trimws(unlist(strsplit(as.character(val_d), ",")))
              d_arr <- d_arr[d_arr != ""]
              if(isTRUE(length(d_arr) == 0)) return(list(vec=c(), str="", media=0))
              
              reps_val <- suppressWarnings(as.numeric(unlist(num_reps)[1]))
              reps <- if (is.null(reps_val) || isTRUE(is.na(reps_val)) || isTRUE(reps_val < 1)) 1 else reps_val
              if(isTRUE(length(d_arr) == 1) && isTRUE(reps > 1)) d_arr <- rep(d_arr, reps)
              
              d_nums <- sapply(d_arr, function(x) {
                pts <- unlist(strsplit(gsub("['\"]", "", x), ":"))
                if(isTRUE(length(pts) < 2)) return(0)
                pt <- suppressWarnings(as.numeric(pts[1]))
                nd <- suppressWarnings(as.numeric(gsub("[^0-9.]", "", pts[2])))
                if(isTRUE(is.na(pt)) || isTRUE(is.na(nd)) || isTRUE(nd == 0)) return(0)
                return(pt / nd)
              })
              return(list(vec = d_nums, str = paste(d_arr, collapse=" | "), media = mean(d_nums, na.rm=T)))
            }

            # 5. CALCULADORA PURA
            calc_carga_serie <- function(v_vec, i_vec) {
              if(isTRUE(length(v_vec) == 0) || isTRUE(length(i_vec) == 0)) return(list(vec=c(), str="", total=0))
              max_l <- max(length(v_vec), length(i_vec))
              v_f <- rep(v_vec, length.out=max_l)
              i_f <- rep(i_vec, length.out=max_l)
              c_vec <- v_f * i_f
              return(list(vec = c_vec, str = paste(round(c_vec, 3), collapse=" | "), total = sum(c_vec, na.rm=T)))
            }

            # --- EJECUCIÓN ---
            cv <- calc_v(info$vel_dist, info$vel_reps, prueba_m)
            cp <- calc_v(info$prin_dist, info$prin_reps, prueba_m)

            vias_sesion <- trimws(unlist(strsplit(as.character(obj_val), "\\+")))
            ci_vel <- calc_i(vias_sesion, prueba_m, info$vel_ritmo, info$vel_reps)
            ci_prin <- calc_i(vias_sesion, prueba_m, info$prin_ritmo, info$prin_reps)

            cd_vel <- calc_d(info$vel_densidad, info$vel_reps)
            cd_prin <- calc_d(info$prin_densidad, info$prin_reps)
            
            cg_vel <- calc_carga_serie(cv$vec, ci_vel$vec)
            cg_prin <- calc_carga_serie(cp$vec, ci_prin$vec)
            
            carga_total_calc <- round(cg_vel$total + cg_prin$total, 3)
            
            densidad_media_calc <- mean(c(cd_vel$media, cd_prin$media), na.rm=T)
            if(isTRUE(is.nan(densidad_media_calc)) || isTRUE(is.na(densidad_media_calc))) densidad_media_calc <- 0

            # --- EMPAQUETADO AL JSON ---
            tmp_met <- list(
              vel_dist = info$vel_dist, vel_reps = info$vel_reps, vel_ritmo = info$vel_ritmo,
              vel_vol_ser = cv$str, vel_vol_tot = cv$t, vel_intensidad = ci_vel$str, vel_densidad_str = cd_vel$str, vel_carga_ser = cg_vel$str, vel_carga_tot = cg_vel$total,
              prin_dist = info$prin_dist, prin_reps = info$prin_reps, prin_ritmo = info$prin_ritmo,
              prin_vol_ser = cp$str, prin_vol_tot = cp$t, prin_intensidad = ci_prin$str, prin_densidad_str = cd_prin$str, prin_carga_ser = cg_prin$str, prin_carga_tot = cg_prin$total,
              vol_tot = cv$t + cp$t,
              carga_tot = carga_total_calc,
              densidad_media_sesion = densidad_media_calc
            )

            tmp_est <- list(
              calentamiento = info$calentamiento,
              vel_desc = info$vel_desc, vel_reps = info$vel_reps, vel_ritmo = info$vel_ritmo, vel_dist = info$vel_dist, vel_rec_s = info$vel_rec_s, vel_rec_b = info$vel_rec_b, vel_densidad = info$vel_densidad,
              prin_desc = info$prin_desc, prin_reps = info$prin_reps, prin_ritmo = info$prin_ritmo, prin_dist = info$prin_dist, prin_rec_s = info$prin_rec_s, prin_rec_b = info$prin_rec_b, prin_densidad = info$prin_densidad
            )

            dbExecute(con, "UPDATE sesion SET estructura=$1, metricas_generales=CAST($2 AS jsonb) WHERE fecha=$3 AND grupo_id=$4",
                      list(toJSON(tmp_est, auto_unbox=T), toJSON(tmp_met, auto_unbox=T), fec_val, g_id))
          }
        }
      }
      dbCommit(con); removeModal(); showNotification("Sincronizado. Cargas por serie guardadas.", type="message")
    }, error = function(e) { try(dbRollback(con)); removeModal(); showNotification(paste("Error:", e$message), type="error") })
  })
  
  # --- RENDERIZADO VISUAL ---
  crear_celda <- function(meso_id, nombre_meso, tipo, f1, s1, f2, s2, temp_id) {
    opts <- c("", "Ajuste", "Carga", "Impacto", "Recuperación", "Aproximación", "Competición")
    paste0("<div style='margin-bottom:5px; border-bottom: 2px solid #3c8dbc;'><b>", nombre_meso, "</b></div>",
      "<select class='select-micro' id='sel_", temp_id, "'>", 
      paste(lapply(opts, function(o) { sel <- if(!is.na(tipo) && o == tipo) "selected" else ""; paste0("<option value='", o, "' ", sel, ">", o, "</option>") }), collapse=""), "</select>",
      "<div class='sesion-container'>", 
        sprintf("<button class='btn-config btn-config-js' data-sid='s1_t%s'>⚙️</button>", temp_id),
        "<label>S1:</label><input type='date' class='input-fecha' id='f1_", temp_id, "' value='", f1, "'><input type='text' class='input-sesion' id='s1_", temp_id, "' value='", s1, "'></div>",
      "<div class='sesion-container'>", 
        sprintf("<button class='btn-config btn-config-js' data-sid='s2_t%s'>⚙️</button>", temp_id),
        "<label>S2:</label><input type='date' class='input-fecha' id='f2_", temp_id, "' value='", f2, "'><input type='text' class='input-sesion' id='s2_", temp_id, "' value='", s2, "'></div>",
      "<div>", sprintf("<button class='btn-add btn-add-js' data-meso='%s' class='btn-add'>+</button>", meso_id), sprintf("<button class='btn-del btn-del-js' data-meso='%s' data-temp='%s' class='btn-del'>-</button>", meso_id, temp_id), "</div>")
  }

  output$render_trimestres <- renderUI({
    refresh_trigger(); data <- isolate(plan_borrador()); req(data)
    lapply(1:4, function(i) {
      m_ids <- unique(as.numeric(data$macro_id))
      if(length(m_ids) < i) return(NULL)
      
      # 1. Filtramos y generamos la posición física
      df_t <- data %>% filter(as.numeric(macro_id) == m_ids[i]) %>% mutate(pos = row_number())
      
      # 2. Creamos la celda y distribuimos usando la posición física
      fila <- df_t %>% 
        rowwise() %>% mutate(html = crear_celda(meso_id, nombre_meso, tipo_micro, f1, s1, f2, s2, temp_id)) %>% 
        ungroup() %>% select(pos, html) %>% spread(pos, html)
      
      box(title = paste("Trimestre", i), width = 12, status = "primary", solidHeader = TRUE, 
          div(style = 'overflow-x: auto;', 
              renderDT(datatable(fila, escape=F, rownames=F, selection='none', 
                                 colnames = paste("Sem", 1:ncol(fila)), 
                                 options = list(dom='t', ordering=F, 
                                                drawCallback = JS('function() { Shiny.bindAll(this.api().table().node()); }'))))))
    })
  })

  # ==========================================
  # --- PESTAÑA: RESULTADOS ATLETAS ---
  # ==========================================

  # 1. Selector de Atletas dinámico (CORREGIDO a nombre_atleta)
  output$selector_atleta_resultados <- renderUI({
    req(input$grupo_activo)
    
    res_atletas <- dbGetQuery(con, sprintf("SELECT atleta_id, nombre_atleta FROM atletas WHERE grupo_id = %s", as.numeric(input$grupo_activo)))
    
    if(nrow(res_atletas) > 0) {
      selectInput("atleta_seleccionado", "Selecciona Atleta:", setNames(res_atletas$atleta_id, res_atletas$nombre_atleta))
    } else {
      p("⚠️ No hay atletas asignados a este grupo en la base de datos.", style="color: red;")
    }
  })

  # 2. Selector de Sesiones (Solo muestra la fecha)
  output$ui_selector_sesion <- renderUI({
    req(input$grupo_activo)
    
    query_sesiones <- sprintf("
      SELECT sesion_id, fecha::text, objetivo_sesion, estructura::text 
      FROM sesion 
      WHERE grupo_id = %s 
        AND estructura IS NOT NULL 
        AND estructura::text != '' 
        AND estructura::text != 'null'
      ORDER BY fecha DESC", as.numeric(input$grupo_activo))
    
    sesiones_db <- dbGetQuery(con, query_sesiones)
    
    if(nrow(sesiones_db) > 0) {
      # Dejamos solo la fecha en las opciones
      opciones <- setNames(sesiones_db$sesion_id, sesiones_db$fecha)
      selectInput("sesion_seleccionada", "Selecciona la Sesión a evaluar:", opciones)
    } else {
      p("No hay sesiones con datos estructurados (⚙️) para este grupo.")
    }
  })

  estructura_sesion_activa <- reactiveVal(NULL)

  observeEvent(input$sesion_seleccionada, {
    req(input$sesion_seleccionada)
    est <- dbGetQuery(con, sprintf("SELECT estructura::text FROM sesion WHERE sesion_id = %s", as.numeric(input$sesion_seleccionada)))$estructura[1]
    
    if(!is.na(est) && est != "") {
      estructura_sesion_activa(fromJSON(est))
    } else {
      estructura_sesion_activa(NULL)
    }
  })

  # 3. Mostrar la Información Planificada Limpia (Pestaña Resultados)
  output$info_entreno_limpia <- renderUI({
    datos <- estructura_sesion_activa(); req(datos)
    
    # Mini-función para que si un campo está vacío ponga un guion "-"
    # Mini-función blindada
    limpiar <- function(x) { if(is.null(x) || isTRUE(is.na(x)) || isTRUE(x == "")) return("-") else return(x) }
    
    div(style = "background-color: #f4f6f9; padding: 15px; border-radius: 5px; margin-bottom: 20px;",
      h4(icon("fire"), " Calentamiento"), 
      p(limpiar(datos$calentamiento)), 
      hr(),
      
      h4(icon("bolt"), " Velocidad"), 
      p(HTML(sprintf("<b>Series:</b> %s <br> <b>Recuperación series:</b> %s <br> <b>Recuperación bloques:</b> %s <br> <b>Ritmo:</b> %s", 
                     limpiar(datos$vel_desc), limpiar(datos$vel_rec_s), limpiar(datos$vel_rec_b), limpiar(datos$vel_ritmo)))), 
      hr(),
      
      h4(icon("running"), " Principal"), 
      p(HTML(sprintf("<b>Series:</b> %s <br> <b>Recuperación series:</b> %s <br> <b>Recuperación bloques:</b> %s <br> <b>Ritmo:</b> %s", 
                     limpiar(datos$prin_desc %||% datos$desc), 
                     limpiar(datos$prin_rec_s %||% datos$rec_s), 
                     limpiar(datos$prin_rec_b %||% datos$rec_b), 
                     limpiar(datos$prin_ritmo %||% datos$ritmo))))
    )
  })

  # 4. Generar Inputs Dinámicos (Cambiamos FC por Recuperación)
  output$dinamico_series_resultados <- renderUI({
    datos <- estructura_sesion_activa(); req(datos)
    
    n_v <- suppressWarnings(as.numeric(datos$vel_reps)); if(length(n_v) == 0 || is.na(n_v)) n_v <- 0
    n_p <- suppressWarnings(as.numeric(datos$prin_reps))
    if(length(n_p) == 0 || is.na(n_p)) {
      n_p_old <- suppressWarnings(as.numeric(datos$reps))
      if(length(n_p_old) == 0 || is.na(n_p_old)) n_p <- 1 else n_p <- n_p_old
    }
    
    cajas_velocidad <- if(n_v > 0) {
      lapply(1:n_v, function(i) {
        fluidRow(style = "margin-bottom: 5px;",
          column(2, p(style="font-weight: bold; margin-top: 30px; color: black;", paste("Serie", i, ":"))),
          column(3, textInput(paste0("res_v_tiempo_", i), "Marca", placeholder = "Ej: 12.5s")),
          column(3, textInput(paste0("res_v_rec_", i), "Recuperación", placeholder = "Ej: 1:30 o 90s")),
          column(4, textInput(paste0("res_v_rpe_", i), "RPE", placeholder = "Ej: 8"))
        )
      })
    } else p("No hay series de velocidad planificadas.", style="color: #7f8c8d; font-style: italic;")

    cajas_principal <- if(n_p > 0) {
      lapply(1:n_p, function(i) {
        fluidRow(style = "margin-bottom: 5px;",
          column(2, p(style="font-weight: bold; margin-top: 30px; color:black;", paste("Serie", i, ":"))),
          column(3, textInput(paste0("res_p_tiempo_", i), "Marca", placeholder = "Ej: 1:15")),
          column(3, textInput(paste0("res_p_rec_", i), "Recuperación", placeholder = "Ej: 2:00 o 120s")),
          column(4, textInput(paste0("res_p_rpe_", i), "RPE", placeholder = "Ej: 9"))
        )
      })
    } else p("No hay series principales planificadas.")
    
    # --- INTERFAZ FINAL (Sin checkbox y con comentarios abajo) ---
    tagList(
      h4(icon("bolt"), " Marcas Velocidad"), 
      cajas_velocidad, 
      hr(),
      
      h4(icon("running"), " Marcas Principal"), 
      cajas_principal, 
      hr(),
      
      h4(icon("comments"), " Comentarios Generales del Atleta"),
      # Usamos textAreaInput para que tengan espacio para escribir
      textAreaInput("res_comentarios", NULL, 
                    placeholder = "Sensaciones, molestias, clima, etc...", 
                    width = "100%", rows = 3),
      
      fluidRow(
        column(12, align = "right", style = "margin-top: 15px;",
          actionButton("btn_guardar_resultados_bd", "Guardar Resultados", 
                       icon = icon("save"), class = "btn-success btn-lg")
        )
      )
    )
  })

  # --- BLOQUE PARA CARGAR DATOS PREVIOS (Adaptado a tu tabla real) ---
  observeEvent(c(input$atleta_seleccionado, input$sesion_seleccionada), {
    req(input$atleta_seleccionado, input$sesion_seleccionada)
    
    # Buscamos usando solo atleta_id y sesion_id
    res_db <- tryCatch(
      dbGetQuery(con, sprintf("
        SELECT resultados 
        FROM resultados_sesion 
        WHERE atleta_id = %s AND sesion_id = %s
      ", as.numeric(input$atleta_seleccionado), as.numeric(input$sesion_seleccionada))), 
      error = function(e) data.frame()
    )
    
    if(nrow(res_db) > 0) {
      # Parseamos el JSON de los resultados
      lista_res <- tryCatch(jsonlite::fromJSON(res_db$resultados[1]), error = function(e) list())
      
      # Cargamos comentarios desde dentro del JSON (si existen)
      val_comentarios <- if(!is.null(lista_res$comentarios)) lista_res$comentarios else ""
      updateTextAreaInput(session, "res_comentarios", value = val_comentarios)
      
      # Rellenamos las cajitas de Velocidad
      if(!is.null(lista_res$velocidad)) {
        for(i in 1:length(lista_res$velocidad$tiempo)) {
          updateTextInput(session, paste0("res_v_tiempo_", i), value = lista_res$velocidad$tiempo[i])
          updateTextInput(session, paste0("res_v_rec_", i), value = lista_res$velocidad$rec[i])
          updateTextInput(session, paste0("res_v_rpe_", i), value = lista_res$velocidad$rpe[i])
        }
      }
      
      # Rellenamos las cajitas de Principal
      if(!is.null(lista_res$principal)) {
        for(i in 1:length(lista_res$principal$tiempo)) {
          updateTextInput(session, paste0("res_p_tiempo_", i), value = lista_res$principal$tiempo[i])
          updateTextInput(session, paste0("res_p_rec_", i), value = lista_res$principal$rec[i])
          updateTextInput(session, paste0("res_p_rpe_", i), value = lista_res$principal$rpe[i])
        }
      }
    } else {
      # Si no hay datos, limpiamos el cuadro de comentarios
      updateTextAreaInput(session, "res_comentarios", value = "")
    }
  })

  # --- GUARDAR RESULTADOS Y CÁLCULO DE MÉTRICAS REALES ---
  observeEvent(input$btn_guardar_resultados_bd, {
    req(input$atleta_seleccionado, input$sesion_seleccionada)
    datos_plan <- estructura_sesion_activa()
    req(datos_plan)
    
    showModal(modalDialog("Procesando telemetría y guardando...", footer=NULL))
    
    tryCatch({
      # 1. IDs
      a_id <- as.numeric(input$atleta_seleccionado)
      s_id <- as.numeric(input$sesion_seleccionada)

      # 2. INFO DEL ATLETA
      info_atleta <- dbGetQuery(con, sprintf("
        SELECT a.referencia, g.pruebas 
        FROM atletas a JOIN grupos_entrenamiento g ON a.grupo_id = g.grupo_id 
        WHERE a.atleta_id = %s", a_id))
      
      ref_100 <- if(nrow(info_atleta) > 0 && !is.na(info_atleta$referencia)) as.numeric(info_atleta$referencia) else 0
      prueba_m <- if(nrow(info_atleta) > 0 && !is.na(info_atleta$pruebas)) as.numeric(info_atleta$pruebas) else 1000

      # 3. TRADUCTOR BASE
      traducir_ritmo <- function(via_metabolica, prueba_ref, ritmo_txt) {
        if(is.null(ritmo_txt) || length(ritmo_txt) == 0 || is.na(ritmo_txt[1]) || as.character(ritmo_txt[1]) == "") return(NA)
        r_clean <- gsub("[ \"']", "", tolower(as.character(ritmo_txt[1])))
        if(r_clean %in% c("atope", "max", "máx", "100", "100%")) r_clean <- "100%"
        if(grepl("ritmo(1000|800|2000)", r_clean)) r_clean <- "0"
        
        dict <- data.frame(
          shiny = c(9.0, 8.0, 7.2, 7.1, 6.3, 6.2, 6.1, 5.5, 5.4, 5.3, 5.2, 5.1, 4.5, 4.4, 4.3, 4.2, 4.1, 3.3, 3.2, 3.1, 2.2, 2.1, 1.0),
          ref_1000 = c("100%", "100%", "-5/95%", "-4/90%", "-3", "-2", "-1", "0", "+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9", "ritmo4000", "ritmo5000", "ritmo6000", "ritmo8000", "ritmo10000", "+ritmo10000"),
          ref_800  = c("100%", "100%", "-4/95%", "-3/90%", "-2", "-1", "0", "+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9", "+10", "ritmo4000", "ritmo5000", "ritmo6000", "ritmo8000", "ritmo10000", "+ritmo10000"),
          ref_2000 = c("100%", "100%", "-10/95%", "-9/90%", "-8", "-7", "-6", "-5", "-4", "-3", "-2", "-1", "0", "+1", "+2", "+3", "+4", "ritmo4000", "ritmo5000", "ritmo6000", "ritmo8000", "ritmo10000", "+ritmo10000"),
          stringsAsFactors = FALSE
        )
        col_buscar <- "ref_1000"
        if(!is.na(prueba_ref)) {
          if(prueba_ref == 800) col_buscar <- "ref_800"
          if(prueba_ref == 2000) col_buscar <- "ref_2000"
        }
        r_cmp <- gsub("\\+", "", r_clean)
        for(j in 1:nrow(dict)) {
          opts <- gsub("[ \"']", "", tolower(unlist(strsplit(dict[[col_buscar]][j], "/"))))
          opts_sin_mas <- gsub("\\+", "", opts)
          if(r_cmp %in% opts_sin_mas || r_clean %in% opts) return(dict$shiny[j])
        }
        return(NA) 
      }

      # 4. CONVERSOR DE TIEMPO BLINDADO
      parse_seg <- function(txt) {
        if(is.null(txt) || isTRUE(is.na(txt)) || isTRUE(txt == "")) return(NA)
        t_clean <- tolower(gsub("[^0-9:.,]", "", txt))
        if(grepl(":", t_clean)) {
          pts <- as.numeric(unlist(strsplit(t_clean, ":")))
          return(pts[1] * 60 + pts[2])
        }
        return(suppressWarnings(as.numeric(gsub(",", ".", t_clean))))
      }

      # 5. PROCESADOR DE SERIES BLINDADO (Resultados Reales)
      procesar_bloque <- function(n_reps, prefix, dist_string) {
        if(is.null(n_reps) || isTRUE(is.na(n_reps)) || isTRUE(n_reps < 1)) return(list(vol=0, v_s="", i_s="", d_s="", c_s="", carga_tot=0, d_media=0, res=list()))
        d_arr <- suppressWarnings(as.numeric(unlist(strsplit(gsub("[^0-9,.]", "", as.character(dist_string)), ","))))
        d_arr <- d_arr[!is.na(d_arr)]; if(length(d_arr) == 0) d_arr <- 0
        if(length(d_arr) < n_reps) d_arr <- rep(d_arr, length.out = n_reps)
        
        v_ser <- c(); i_ser <- c(); d_ratio_str <- c(); d_ratio_num <- c(); c_ser <- c()
        tiempos <- c(); recs <- c(); rpes <- c()
        
        for(i in 1:n_reps) {
          t_txt <- input[[paste0(prefix, "tiempo_", i)]]; r_txt <- input[[paste0(prefix, "rec_", i)]]; rpe_txt <- input[[paste0(prefix, "rpe_", i)]]
          tiempos <- c(tiempos, if(is.null(t_txt) || isTRUE(is.na(t_txt))) "" else t_txt)
          recs <- c(recs, if(is.null(r_txt) || isTRUE(is.na(r_txt))) "" else r_txt)
          rpes <- c(rpes, if(is.null(rpe_txt) || isTRUE(is.na(rpe_txt))) "" else rpe_txt)
          
          seg_t <- parse_seg(t_txt); seg_r <- parse_seg(r_txt); dist <- d_arr[i]
          
          v_val <- if(isTRUE(dist > 0) && isTRUE(prueba_m > 0)) dist / prueba_m else 0
          v_ser <- c(v_ser, v_val)
          
          i_val <- 0
          if(isTRUE(seg_t > 0) && isTRUE(dist > 0) && isTRUE(ref_100 > 0)) {
            ritmo_100_real <- (seg_t / dist) * 100
            diff <- round(ritmo_100_real - ref_100)
            txt_para_traductor <- if(isTRUE(diff > 0)) paste0("+", diff) else as.character(diff)
            res_shiny <- traducir_ritmo("", prueba_m, txt_para_traductor)
            if(!is.na(res_shiny)) i_val <- res_shiny
          }
          i_ser <- c(i_ser, i_val)
          
          d_str <- "0"; d_num <- 0
          if(isTRUE(seg_t > 0) && isTRUE(seg_r > 0)) {
            ratio <- round(seg_r / seg_t, 2)
            d_str <- paste0("1:", ratio)
            d_num <- 1 / ratio
          }
          d_ratio_str <- c(d_ratio_str, d_str)
          d_ratio_num <- c(d_ratio_num, d_num)
          
          # Carga Pura Aislada
          c_val <- v_val * i_val
          c_ser <- c(c_ser, c_val)
        }
        
        list(
          vol=sum(v_ser), 
          v_s=paste(round(v_ser,3), collapse=" | "), 
          i_s=paste(i_ser, collapse=" | "), 
          d_s=paste(d_ratio_str, collapse=" | "), 
          c_s=paste(round(c_ser,3), collapse=" | "),
          carga_tot=sum(c_ser, na.rm=T), 
          d_media=mean(d_ratio_num[d_ratio_num > 0], na.rm=T), 
          res=list(tiempo=tiempos, rec=recs, rpe=rpes)
        )
      }

      n_v <- suppressWarnings(as.numeric(unlist(datos_plan$vel_reps)[1])); if(isTRUE(is.na(n_v))) n_v <- 0
      n_p <- suppressWarnings(as.numeric(unlist(datos_plan$prin_reps)[1])); if(isTRUE(is.na(n_p))) n_p <- 0
      
      rv <- procesar_bloque(n_v, "res_v_", datos_plan$vel_dist)
      rp <- procesar_bloque(n_p, "res_p_", datos_plan$prin_dist)
      
      json_resultados <- toJSON(list(velocidad = rv$res, principal = rp$res, comentarios = input$res_comentarios), auto_unbox=T)
      
      # Manejo de la densidad media total para el JSON
      d_med_v <- if(is.nan(rv$d_media) || is.na(rv$d_media)) 0 else rv$d_media
      d_med_p <- if(is.nan(rp$d_media) || is.na(rp$d_media)) 0 else rp$d_media
      d_med_tot <- mean(c(d_med_v, d_med_p)[c(d_med_v, d_med_p) > 0], na.rm=T)
      if(is.nan(d_med_tot)) d_med_tot <- 0

      # --- EMPAQUETADO AL JSON (REALIDAD) ---
      tmp_met_real <- list(
        # Bloque Velocidad
        vel_dist = datos_plan$vel_dist,
        vel_reps = n_v,
        vel_ritmo = datos_plan$vel_ritmo,
        vel_vol_ser = rv$v_s,
        vel_vol_tot = rv$vol, 
        vel_intensidad = rv$i_s, 
        vel_densidad_str = rv$d_s, 
        vel_carga_ser = rv$c_s, 
        vel_carga_tot = rv$carga_tot,
        
        # Bloque Principal
        prin_dist = datos_plan$prin_dist,
        prin_reps = n_p,
        prin_ritmo = datos_plan$prin_ritmo,
        prin_vol_ser = rp$v_s, 
        prin_vol_tot = rp$vol, 
        prin_intensidad = rp$i_s, 
        prin_densidad_str = rp$d_s, 
        prin_carga_ser = rp$c_s, 
        prin_carga_tot = rp$carga_tot,
        
        # Totales de la Sesión
        vol_tot = rv$vol + rp$vol,
        carga_tot = round(rv$carga_tot + rp$carga_tot, 3),
        densidad_media_sesion = d_med_tot
      )

      # 7. GUARDAR EN SUPABASE (SOLO 4 COLUMNAS)
      dbExecute(con, "
        INSERT INTO resultados_sesion (atleta_id, sesion_id, resultados, metricas_generales)
        VALUES ($1, $2, CAST($3 AS jsonb), CAST($4 AS jsonb))
        ON CONFLICT (atleta_id, sesion_id) 
        DO UPDATE SET resultados = EXCLUDED.resultados, metricas_generales = EXCLUDED.metricas_generales
      ", list(a_id, s_id, json_resultados, toJSON(tmp_met_real, auto_unbox=T)))
      
      removeModal()
      showNotification("Resultados y métricas del atleta guardados con éxito.", type="message")
      refresh_trigger(rnorm(1))
      
    }, error = function(e) {
      removeModal()
      showNotification(paste("Error al guardar:", e$message), type="error")
    })
  })

  # ==========================================
  # --- PESTAÑA: PERFIL DEL ATLETA ---
  # ==========================================
  
  # 1. Cargar grupos en el desplegable
  observe({
    grupos <- dbGetQuery(con, "SELECT grupo_id, nombre_grupo FROM grupos_entrenamiento")
    if(nrow(grupos) > 0) {
      opciones <- setNames(grupos$grupo_id, grupos$nombre_grupo)
      updateSelectInput(session, "perfil_grupo", choices = opciones)
    }
  })

  # 2. Al seleccionar grupo, cargar los atletas de ese grupo
  observeEvent(input$perfil_grupo, {
    req(input$perfil_grupo)
    atletas <- dbGetQuery(con, sprintf("SELECT atleta_id, nombre_atleta FROM atletas WHERE grupo_id = %s", input$perfil_grupo))
    
    if(nrow(atletas) > 0) {
      opciones_atletas <- setNames(atletas$atleta_id, atletas$nombre_atleta)
      updateSelectInput(session, "perfil_atleta_sel", choices = opciones_atletas)
    } else {
      updateSelectInput(session, "perfil_atleta_sel", choices = character(0))
    }
  })

  # 3. Al seleccionar atleta, traer sus datos de la base de datos
  observeEvent(input$perfil_atleta_sel, {
    req(input$perfil_atleta_sel)
    datos <- dbGetQuery(con, sprintf("SELECT nombre_atleta, marca, referencia, comentarios FROM atletas WHERE atleta_id = %s", input$perfil_atleta_sel))
    
    if(nrow(datos) > 0) {
      updateTextInput(session, "perfil_nombre", value = datos$nombre_atleta[1] %||% "")
      updateNumericInput(session, "perfil_marca", value = datos$marca[1])
      updateNumericInput(session, "perfil_referencia", value = datos$referencia[1])
      updateTextAreaInput(session, "perfil_comentarios", value = datos$comentarios[1] %||% "")
    }
  })

  # 4. Guardar los cambios (Botón "Actualizar Perfil")
  observeEvent(input$btn_guardar_perfil, {
    req(input$perfil_atleta_sel)
    
    a_id <- as.numeric(input$perfil_atleta_sel)
    n_nombre <- input$perfil_nombre
    n_marca <- input$perfil_marca
    n_ref <- input$perfil_referencia
    n_com <- input$perfil_comentarios
    
    # Manejamos los valores vacíos para que PostgreSQL no se enfade con los NULLs
    val_marca <- if(is.na(n_marca) || n_marca == "") NULL else as.numeric(n_marca)
    val_ref <- if(is.na(n_ref) || n_ref == "") NULL else as.numeric(n_ref)
    val_com <- if(is.null(n_com) || n_com == "") NA else n_com
    
    tryCatch({
      # Usamos dbExecute para mandar el UPDATE a la tabla
      dbExecute(con, 
                "UPDATE atletas SET nombre_atleta = $1, marca = $2, referencia = $3, comentarios = $4 WHERE atleta_id = $5", 
                list(n_nombre, val_marca, val_ref, val_com, a_id))
      
      showNotification("¡Perfil actualizado con éxito!", type = "message")
    }, error = function(e) {
      showNotification(paste("Error al guardar:", e$message), type = "error")
    })
  })
  # 1. Cargar grupos en el primer desplegable al iniciar
  observe({
    grupos <- dbGetQuery(con, "SELECT grupo_id, nombre_grupo FROM grupos_entrenamiento")
    if(nrow(grupos) > 0) {
      updateSelectInput(session, "ana_grupo", choices = setNames(grupos$grupo_id, grupos$nombre_grupo))
    }
  })

  # 2. Al cambiar de grupo, cargar sus atletas y sus macrociclos
  observeEvent(input$ana_grupo, {
    req(input$ana_grupo)
    
    # Cargar Atletas
    atletas <- dbGetQuery(con, sprintf("SELECT atleta_id, nombre_atleta FROM atletas WHERE grupo_id = %s", input$ana_grupo))
    opciones_atleta <- c("Teoría del Grupo (Plan)" = "0")
    if(nrow(atletas) > 0) {
      opciones_atleta <- c(opciones_atleta, setNames(atletas$atleta_id, atletas$nombre_atleta))
    }
    updateSelectInput(session, "ana_atleta", choices = opciones_atleta)
    
    # Cargar Macrociclos
    macros <- dbGetQuery(con, sprintf("SELECT macro_id, nombre_macro FROM macrociclo WHERE grupo_id = %s", input$ana_grupo))
    if(nrow(macros) > 0) {
      updateSelectInput(session, "ana_macro", choices = setNames(macros$macro_id, macros$nombre_macro))
    } else {
      updateSelectInput(session, "ana_macro", choices = character(0))
    }
  })

  # 3. Al cambiar de macrociclo, cargar las fechas de sus sesiones
  observeEvent(input$ana_macro, {
    req(input$ana_macro)
    
    sesiones <- dbGetQuery(con, sprintf("
      SELECT s.fecha::text as fecha 
      FROM sesion s 
      JOIN microciclo mi ON s.micro_id = mi.micro_id
      JOIN mesociclo me ON mi.meso_id = me.meso_id
      WHERE me.macro_id = %s ORDER BY s.fecha", input$ana_macro))
      
    if(nrow(sesiones) > 0) {
      updateSelectInput(session, "ana_sesion", choices = sesiones$fecha)
    } else {
      updateSelectInput(session, "ana_sesion", choices = character(0))
    }
  })

  # Cargar los años (temporadas) desde Supabase al abrir la app
  observe({
    res_años <- tryCatch(dbGetQuery(con, "SELECT año_id, nombre_año FROM años ORDER BY nombre_año"), error = function(e) data.frame())
    if(nrow(res_años) > 0) {
      opciones_años <- setNames(res_años$año_id, res_años$nombre_año)
      updateSelectInput(session, "ana_temporada", choices = opciones_años)
    }
  })

  # --- SERVER: ACTUALIZAR ATLETAS SEGÚN EL GRUPO ---
  observeEvent(input$ana_grupo, {
    req(input$ana_grupo) # Esperamos a que haya un grupo seleccionado
    
    # Consultamos los atletas de ese grupo usando tu columna real: nombre_atleta
    res_atle <- tryCatch(
      dbGetQuery(con, sprintf("
        SELECT atleta_id, nombre_atleta 
        FROM atletas 
        WHERE grupo_id = %s
      ", as.numeric(input$ana_grupo))), 
      error = function(e) data.frame()
    )
    
    if(nrow(res_atle) > 0) {
      # Filtro: Eliminamos cualquier cosa que no sea un atleta real
      res_atle <- res_atle[!grepl("Teoría|Plan|Grupo|Borrador", res_atle$nombre_atleta, ignore.case = TRUE), ]
      
      if(nrow(res_atle) > 0) {
        opciones_atle <- setNames(res_atle$atleta_id, res_atle$nombre_atleta)
        updateSelectInput(session, "ana_atleta", choices = opciones_atle)
      } else {
        updateSelectInput(session, "ana_atleta", choices = c("Solo hay grupos teóricos" = ""))
      }
    } else {
      updateSelectInput(session, "ana_atleta", choices = c("No hay atletas" = ""))
    }
  })

  # ==========================================
  # --- MOTOR DE ANÁLISIS ---
  # ==========================================
  datos_analisis <- reactive({
    req(input$ana_grupo)
    refresh_trigger() 
    
    df_db <- tryCatch(dbGetQuery(con, sprintf("
      SELECT s.fecha::date as fecha, mi.meso_id, me.macro_id, s.metricas_generales::text as met_json 
      FROM sesion s JOIN microciclo mi ON s.micro_id = mi.micro_id JOIN mesociclo me ON mi.meso_id = me.meso_id
      WHERE s.grupo_id = %s AND s.fecha IS NOT NULL ORDER BY s.fecha", as.numeric(input$ana_grupo))), error=function(e) data.frame())
    
    if(nrow(df_db) == 0) return(data.frame())

    res <- lapply(df_db$met_json, function(x) {
      m <- tryCatch(jsonlite::fromJSON(x), error = function(e) list())
      
      # 1. Extractor seguro de números simples (Volumen, Carga y Densidad Media)
      safe_num <- function(val) {
        v <- suppressWarnings(as.numeric(unlist(val)[1]))
        if(length(v) == 0 || isTRUE(is.na(v))) return(0)
        return(v)
      }
      
      # 2. Extractor seguro de medias para la intensidad (Ej: "9 | 9" -> 9)
      safe_media <- function(str_val) {
        if(is.null(str_val) || isTRUE(is.na(str_val)) || isTRUE(str_val == "")) return(0)
        v <- suppressWarnings(as.numeric(unlist(strsplit(as.character(str_val), "\\|"))))
        v <- v[!is.na(v)]
        if(length(v) == 0) return(0)
        return(mean(v))
      }
      
      return(list(
        Vol_Vel = safe_num(m$vel_vol_tot), 
        Vol_Prin = safe_num(m$prin_vol_tot),
        Carga_Vel = safe_num(m$vel_carga_tot), 
        Carga_Prin = safe_num(m$prin_carga_tot), 
        Carga_Total = safe_num(m$carga_tot),
        Int_Vel = safe_media(m$vel_intensidad), 
        Int_Prin = safe_media(m$prin_intensidad),
        Dens_Media = safe_num(m$densidad_media_sesion)
      ))
    })

    df <- data.frame(
      fecha = df_db$fecha, macro_id = df_db$macro_id,
      Vol_Vel = sapply(res, function(x) x$Vol_Vel), Vol_Prin = sapply(res, function(x) x$Vol_Prin),
      Carga_Vel = sapply(res, function(x) x$Carga_Vel), Carga_Prin = sapply(res, function(x) x$Carga_Prin), Carga_Total = sapply(res, function(x) x$Carga_Total),
      Int_Vel = sapply(res, function(x) x$Int_Vel), Int_Prin = sapply(res, function(x) x$Int_Prin),
      Dens_Vel = sapply(res, function(x) x$Dens_Media), Dens_Prin = sapply(res, function(x) x$Dens_Media)
    )
    return(df)
  })

  # ==========================================
  # --- MOTOR DE ANÁLISIS (ATLETA - DATOS REALES) ---
  # ==========================================
  datos_analisis_atleta <- reactive({
    req(input$ana_atleta)
    if(input$ana_atleta == "" || input$ana_atleta == "0") return(data.frame())
    refresh_trigger()
    
    df_db <- tryCatch({
      dbGetQuery(con, sprintf("
        SELECT s.fecha::date as fecha, me.macro_id, r.metricas_generales::text as met_json 
        FROM resultados_sesion r 
        JOIN sesion s ON r.sesion_id = s.sesion_id
        JOIN microciclo mi ON s.micro_id = mi.micro_id 
        JOIN mesociclo me ON mi.meso_id = me.meso_id
        WHERE r.atleta_id = %s AND r.metricas_generales IS NOT NULL 
        ORDER BY s.fecha", as.numeric(input$ana_atleta)))
    }, error = function(e) { data.frame() })
    
    if(nrow(df_db) == 0) return(data.frame())

    res <- lapply(df_db$met_json, function(x) {
      m <- tryCatch(jsonlite::fromJSON(x), error = function(e) list())
      
      safe_num <- function(val) {
        v <- suppressWarnings(as.numeric(unlist(val)[1]))
        if(length(v) == 0 || isTRUE(is.na(v))) return(0)
        return(v)
      }
      
      safe_media <- function(str_val) {
        if(is.null(str_val) || isTRUE(is.na(str_val)) || isTRUE(str_val == "")) return(0)
        v <- suppressWarnings(as.numeric(unlist(strsplit(as.character(str_val), "\\|"))))
        v <- v[!is.na(v)]
        if(length(v) == 0) return(0)
        return(mean(v))
      }
      
      return(list(
        Vol_Vel = safe_num(m$vel_vol_tot), Vol_Prin = safe_num(m$prin_vol_tot), 
        Carga_Vel = safe_num(m$vel_carga_tot), Carga_Prin = safe_num(m$prin_carga_tot),
        Carga_Total = safe_num(m$carga_tot),
        Int_Vel = safe_media(m$vel_intensidad), Int_Prin = safe_media(m$prin_intensidad), 
        Dens_Media = safe_num(m$densidad_media_sesion)
      ))
    })

    # AQUÍ ESTABA EL ERROR: Faltaba extraer Carga_Vel y Carga_Prin
    df <- data.frame(
      fecha = df_db$fecha, macro_id = df_db$macro_id,
      Vol_Vel = sapply(res, function(x) x$Vol_Vel), Vol_Prin = sapply(res, function(x) x$Vol_Prin),
      Carga_Vel = sapply(res, function(x) x$Carga_Vel), Carga_Prin = sapply(res, function(x) x$Carga_Prin),
      Carga_Total = sapply(res, function(x) x$Carga_Total),
      Int_Vel = sapply(res, function(x) x$Int_Vel), Int_Prin = sapply(res, function(x) x$Int_Prin),
      Dens_Vel = sapply(res, function(x) x$Dens_Media), Dens_Prin = sapply(res, function(x) x$Dens_Media)
    )
    return(df)
  })

  # ==========================================
  # --- FUNCIÓN AUXILIAR PARA PARSEAR SERIES ---
  # ==========================================
  # Coloca esto justo encima del bloque de gráficas de la sesión (apartados 5 y 6)
  parsear_series_sesion <- function(json_text) {
    if(is.null(json_text) || is.na(json_text) || json_text == "") return(NULL)
    m <- tryCatch(jsonlite::fromJSON(json_text), error = function(e) list())
    
    # Extrae un bloque (Velocidad o Principal) y lo convierte en filas
    extraer_bloque <- function(carga_str, dens_str, nombre_bloque) {
      if (is.null(carga_str) || is.na(carga_str) || carga_str == "") return(NULL)
      
      cargas <- suppressWarnings(as.numeric(trimws(unlist(strsplit(as.character(carga_str), "\\|")))))
      cargas[is.na(cargas)] <- 0
      
      dens_raw <- trimws(unlist(strsplit(as.character(dens_str), "\\|")))
      dens_num <- sapply(dens_raw, function(x) {
        if (grepl(":", x)) {
          pts <- suppressWarnings(as.numeric(unlist(strsplit(x, ":"))))
          if (length(pts) >= 2 && !is.na(pts[2]) && pts[2] > 0) return(pts[1]/pts[2]) else return(0)
        } else {
          val <- suppressWarnings(as.numeric(x))
          return(if(is.na(val)) 0 else val)
        }
      })
      
      n <- max(length(cargas), length(dens_num))
      if(n == 0) return(NULL)
      
      if(length(cargas) < n) cargas <- rep(cargas, length.out = n)
      if(length(dens_num) < n) dens_num <- rep(dens_num, length.out = n)
      
      data.frame(
        Bloque = factor(nombre_bloque, levels = c("Velocidad", "Principal")),
        Serie = 1:n,
        Carga = cargas,
        Densidad = dens_num,
        stringsAsFactors = FALSE
      )
    }
    
    df_vel <- extraer_bloque(m$vel_carga_ser, m$vel_densidad_str, "Velocidad")
    df_prin <- extraer_bloque(m$prin_carga_ser, m$prin_densidad_str, "Principal")
    
    df_final <- bind_rows(df_vel, df_prin)
    if(nrow(df_final) == 0) return(NULL)
    return(df_final)
  }

  # ==========================================
  # --- FUNCIÓN: CONSTRUIR TIMELINE DE SERIES ---
  # ==========================================
  # Extrae una métrica segura de la base de datos (Ej: "1.5 | 1.8" -> c(1.5, 1.8))
  extraer_array_nums <- function(texto) {
    if(is.null(texto) || is.na(texto) || texto == "") return(numeric(0))
    suppressWarnings(as.numeric(trimws(unlist(strsplit(as.character(texto), "\\|")))))
  }

  # Convierte textos como "1:30" o "90s" a segundos puros
  parse_segundos_global <- function(txt) {
    if(is.null(txt) || isTRUE(is.na(txt)) || isTRUE(txt == "")) return(60) # Recuperación por defecto si está vacío
    t_clean <- tolower(gsub("[^0-9:.,]", "", as.character(txt)))
    if(grepl(":", t_clean)) {
      pts <- as.numeric(unlist(strsplit(t_clean, ":")))
      return(pts[1] * 60 + pts[2])
    }
    val <- suppressWarnings(as.numeric(gsub(",", ".", t_clean)))
    if(is.na(val) || val <= 0) return(60)
    return(val)
  }

  generar_df_timeline <- function(met_json, rec_teoria_s_vel, rec_teoria_s_prin, rec_atleta_array_vel, rec_atleta_array_prin, tipo = "teoria") {
    m <- tryCatch(jsonlite::fromJSON(met_json), error = function(e) list())
    
    construir_bloque <- function(vols_str, ints_str, rec_teo, rec_atl, nombre_bloque) {
      vols <- extraer_array_nums(vols_str); vols[is.na(vols)] <- 0
      ints <- extraer_array_nums(ints_str); ints[is.na(ints)] <- 0
      n <- max(length(vols), length(ints))
      if(n == 0) return(NULL)
      if(length(vols) < n) vols <- rep(vols, length.out = n)
      if(length(ints) < n) ints <- rep(ints, length.out = n)
      
      # Obtener el array de recuperaciones en segundos
      recs_seg <- rep(60, n)
      if(tipo == "teoria") {
        # La teoría suele tener una sola recuperación para todo el bloque (ej: "90")
        val_teo <- parse_segundos_global(rec_teo)
        recs_seg <- rep(val_teo, n)
      } else {
        # La realidad tiene un array real (ej: ["90", "120", "60"])
        if(!is.null(rec_atl) && length(rec_atl) > 0) {
          recs_seg <- sapply(rec_atl, parse_segundos_global)
          if(length(recs_seg) < n) recs_seg <- rep(recs_seg, length.out = n)
        }
      }
      
      # Calcular la posición X acumulativa
      x_pos <- numeric(n)
      x_pos[1] <- 0
      if(n > 1) {
        for(i in 2:n) {
          gap <- recs_seg[i-1]
          x_pos[i] <- x_pos[i-1] + gap + 20 # Sumamos el gap + un ancho base para la barra
        }
      }
      
      data.frame(Bloque = nombre_bloque, Serie = 1:n, X_centro = x_pos, Volumen = vols, Intensidad = ints, stringsAsFactors = FALSE)
    }
    
    df_vel <- construir_bloque(m$vel_vol_ser, m$vel_intensidad, rec_teoria_s_vel, rec_atleta_array_vel, "Velocidad")
    df_prin <- construir_bloque(m$prin_vol_ser, m$prin_intensidad, rec_teoria_s_prin, rec_atleta_array_prin, "Principal")
    
    bind_rows(df_vel, df_prin)
  }

  # ==========================================
  # 7. TIMELINE DE SERIES (TEORÍA)
  # ==========================================
  output$grafica_timeline_teoria <- renderPlot({
    req(input$ana_sesion, input$ana_grupo)
    
    res_db <- tryCatch(dbGetQuery(con, sprintf("
      SELECT metricas_generales::text as met, estructura::text as est 
      FROM sesion WHERE grupo_id = %s AND fecha = '%s' LIMIT 1", 
      as.numeric(input$ana_grupo), input$ana_sesion)), error = function(e) data.frame())
    req(nrow(res_db) > 0)
    
    est <- tryCatch(jsonlite::fromJSON(res_db$est[1]), error = function(e) list())
    
    df <- generar_df_timeline(res_db$met[1], est$vel_rec_s, est$prin_rec_s, NULL, NULL, tipo = "teoria")
    req(!is.null(df) && nrow(df) > 0)
    
    # Coeficiente para igualar el tamaño visual del Volumen (pequeño) y la Intensidad (grande)
    coeff <- if(max(df$Volumen, na.rm=T) > 0) max(df$Intensidad, na.rm=T) / max(df$Volumen, na.rm=T) else 1
    if(coeff == 0 || is.na(coeff)) coeff <- 1
    
    # Preparamos los datos forzando el desvío manual de las columnas en el eje X
    ancho_barra <- 15 # Ancho en "segundos" de la barra
    df_plot <- bind_rows(
      df %>% mutate(X_plot = X_centro - ancho_barra/2, Valor = Volumen, Metrica = "Volumen"),
      df %>% mutate(X_plot = X_centro + ancho_barra/2, Valor = Intensidad / coeff, Metrica = "Intensidad")
    )
    
    ggplot(df_plot, aes(x = X_plot, y = Valor, fill = Metrica)) +
      geom_col(width = ancho_barra, color = "black", alpha = 0.9) +
      scale_y_continuous(name = "Volumen", sec.axis = sec_axis(~.*coeff, name = "Intensidad")) +
      scale_fill_manual(values = c("Volumen" = "#3498db", "Intensidad" = "#e74c3c")) +
      facet_wrap(~ Bloque, scales = "free", ncol = 1) +
      theme_minimal(base_size = 14) +
      labs(x = "Timeline (Espaciado = Segundos de Recuperación)", title = "Espaciado por Tiempos Planificados") +
      theme(legend.position = "top", strip.background = element_rect(fill = "#2c3e50"), strip.text = element_text(color = "white", face = "bold"))
  })

  # ==========================================
  # 8. TIMELINE DE SERIES (ATLETA)
  # ==========================================
  output$grafica_timeline_atleta <- renderPlot({
    req(input$ana_sesion, input$ana_atleta)
    
    res_db <- tryCatch(dbGetQuery(con, sprintf("
      SELECT r.metricas_generales::text as met, r.resultados::text as res 
      FROM resultados_sesion r JOIN sesion s ON r.sesion_id = s.sesion_id
      WHERE r.atleta_id = %s AND s.fecha = '%s' LIMIT 1", 
      as.numeric(input$ana_atleta), input$ana_sesion)), error = function(e) data.frame())
    req(nrow(res_db) > 0)
    
    res_atl <- tryCatch(jsonlite::fromJSON(res_db$res[1]), error = function(e) list())
    
    df <- generar_df_timeline(res_db$met[1], NULL, NULL, res_atl$velocidad$rec, res_atl$principal$rec, tipo = "atleta")
    req(!is.null(df) && nrow(df) > 0)
    
    coeff <- if(max(df$Volumen, na.rm=T) > 0) max(df$Intensidad, na.rm=T) / max(df$Volumen, na.rm=T) else 1
    if(coeff == 0 || is.na(coeff)) coeff <- 1
    
    ancho_barra <- 15
    df_plot <- bind_rows(
      df %>% mutate(X_plot = X_centro - ancho_barra/2, Valor = Volumen, Metrica = "Volumen REAL"),
      df %>% mutate(X_plot = X_centro + ancho_barra/2, Valor = Intensidad / coeff, Metrica = "Intensidad REAL")
    )
    
    ggplot(df_plot, aes(x = X_plot, y = Valor, fill = Metrica)) +
      geom_col(width = ancho_barra, color = "black", alpha = 0.9) +
      scale_y_continuous(name = "Volumen REAL", sec.axis = sec_axis(~.*coeff, name = "Intensidad REAL")) +
      scale_fill_manual(values = c("Volumen REAL" = "#2980b9", "Intensidad REAL" = "#c0392b")) +
      facet_wrap(~ Bloque, scales = "free", ncol = 1) +
      theme_minimal(base_size = 14) +
      labs(x = "Timeline (Espaciado = Recuperación REAL)", title = "Espaciado por Tiempos Ejecutados") +
      theme(legend.position = "top", strip.background = element_rect(fill = "#d35400"), strip.text = element_text(color = "white", face = "bold"))
  })

  # ==========================================
  # --- GRÁFICAS DE ÉLITE (CON PATCHWORK 1:3) ---
  # ==========================================
  
  # 1. MACROCICLO (TEORÍA)
  output$grafica_macro <- renderPlot({
    req(input$ana_macro); df <- datos_analisis() %>% filter(macro_id == as.numeric(input$ana_macro), Carga_Total > 0); req(nrow(df) > 0)
    
    p1 <- ggplot(df, aes(x = as.factor(fecha), y = Dens_Vel)) +
      geom_line(aes(group = 1), color = "#e74c3c", size = 1.5) +
      geom_point(color = "#e74c3c", size = 4) +
      theme_minimal(base_size = 14) +
      labs(x = NULL, y = "Densidad", title = "Macrociclo Planificado: Trabajo vs Fatiga") +
      theme(axis.text.x = element_blank(), axis.title.y = element_text(color = "#e74c3c", face = "bold"))
      
    p2 <- ggplot(df, aes(x = as.factor(fecha), y = Carga_Total)) +
      geom_col(fill = "#2c3e50", alpha = 0.85, width = 0.6) +
      theme_minimal(base_size = 14) +
      labs(x = "Sesiones", y = "Carga Total") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"), axis.title.y = element_text(color = "#2c3e50", face = "bold"))
      
    p1 / p2 + plot_layout(heights = c(1, 3)) # <- Magia: Proporción 1 a 3
  })

  # 2. MACROCICLO (ATLETA - REALIDAD)
  output$grafica_macro_atleta <- renderPlot({
    req(input$ana_macro); df <- datos_analisis_atleta() %>% filter(macro_id == as.numeric(input$ana_macro), Carga_Total > 0); req(nrow(df) > 0)
    
    p1 <- ggplot(df, aes(x = as.factor(fecha), y = Dens_Vel)) +
      geom_line(aes(group = 1), color = "#27ae60", size = 1.5) +
      geom_point(color = "#27ae60", size = 4) +
      theme_minimal(base_size = 14) +
      labs(x = NULL, y = "Dens. REAL", title = "Macrociclo REAL: Trabajo vs Fatiga") +
      theme(axis.text.x = element_blank(), axis.title.y = element_text(color = "#27ae60", face = "bold"))
      
    p2 <- ggplot(df, aes(x = as.factor(fecha), y = Carga_Total)) +
      geom_col(fill = "#d35400", alpha = 0.85, width = 0.6) +
      theme_minimal(base_size = 14) +
      labs(x = "Sesiones", y = "Carga REAL") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"), axis.title.y = element_text(color = "#d35400", face = "bold"))
      
    p1 / p2 + plot_layout(heights = c(1, 3))
  })

  # 3. ANUAL (TEORÍA) - DASHBOARD POR TRIMESTRES (TODO BARRAS + EJE X COMPARTIDO)
  output$grafica_anual <- renderPlot({
    df <- datos_analisis() %>% filter(Carga_Total > 0); req(nrow(df) > 0)
    
    df <- df %>% rowwise() %>% mutate(
      Vol_Tot = Vol_Vel + Vol_Prin,
      Int_Media_Sesion = mean(c(Int_Vel, Int_Prin)[c(Int_Vel, Int_Prin) > 0], na.rm=TRUE)
    ) %>% ungroup() %>% mutate(Int_Media_Sesion = ifelse(is.nan(Int_Media_Sesion), 0, Int_Media_Sesion))
    
    df_res <- df %>% group_by(macro_id) %>% summarise(
      Volumen = mean(Vol_Tot, na.rm = TRUE),
      Intensidad = mean(Int_Media_Sesion, na.rm = TRUE),
      Densidad = mean(Dens_Vel, na.rm = TRUE),
      Carga_Gen = mean(Carga_Total * (1 + Dens_Vel), na.rm = TRUE)
    ) %>% arrange(macro_id) %>% mutate(Trimestre = paste("Trim.", row_number()))
    
    # Fila Superior (p1 y p2): Ocultamos el texto del eje X
    p1 <- ggplot(df_res, aes(x = Trimestre, y = Volumen)) +
      geom_col(fill = "#3498db", alpha = 0.85, width = 0.5) +
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Volumen Medio") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_blank())
      
    p2 <- ggplot(df_res, aes(x = Trimestre, y = Intensidad)) +
      geom_col(fill = "#e74c3c", alpha = 0.85, width = 0.5) + # Cambiado a barras
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Intensidad Media") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_blank())
      
    # Fila Inferior (p3 y p4): Mantenemos el texto del eje X
    p3 <- ggplot(df_res, aes(x = Trimestre, y = Densidad)) +
      geom_col(fill = "#2c3e50", alpha = 0.85, width = 0.5) + # Cambiado a barras
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Densidad Media") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_text(face="bold"))
      
    p4 <- ggplot(df_res, aes(x = Trimestre, y = Carga_Gen)) +
      geom_col(fill = "#9b59b6", alpha = 0.85, width = 0.5) +
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Carga Media") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_text(face="bold"))
      
    (p1 | p2) / (p3 | p4) + plot_annotation(title = "Medias por Trimestre (Teoría / Planificado)", theme = theme(plot.title = element_text(size = 16, face = "bold", hjust = 0.5, color="#2c3e50")))
  })

  # 4. ANUAL (ATLETA - REALIDAD) - DASHBOARD POR TRIMESTRES (TODO BARRAS + EJE X COMPARTIDO)
  output$grafica_anual_atleta <- renderPlot({
    df <- datos_analisis_atleta() %>% filter(Carga_Total > 0); req(nrow(df) > 0)
    
    df <- df %>% rowwise() %>% mutate(
      Vol_Tot = Vol_Vel + Vol_Prin,
      Int_Media_Sesion = mean(c(Int_Vel, Int_Prin)[c(Int_Vel, Int_Prin) > 0], na.rm=TRUE)
    ) %>% ungroup() %>% mutate(Int_Media_Sesion = ifelse(is.nan(Int_Media_Sesion), 0, Int_Media_Sesion))
    
    df_res <- df %>% group_by(macro_id) %>% summarise(
      Volumen = mean(Vol_Tot, na.rm = TRUE),
      Intensidad = mean(Int_Media_Sesion, na.rm = TRUE),
      Densidad = mean(Dens_Vel, na.rm = TRUE),
      Carga_Gen = mean(Carga_Total * (1 + Dens_Vel), na.rm = TRUE)
    ) %>% arrange(macro_id) %>% mutate(Trimestre = paste("Trim.", row_number()))
    
    # Fila Superior (Ocultamos el eje X)
    p1 <- ggplot(df_res, aes(x = Trimestre, y = Volumen)) +
      geom_col(fill = "#2980b9", alpha = 0.85, width = 0.5) +
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Volumen Medio") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_blank())
      
    p2 <- ggplot(df_res, aes(x = Trimestre, y = Intensidad)) +
      geom_col(fill = "#c0392b", alpha = 0.85, width = 0.5) + # Cambiado a barras
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Intensidad Media") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_blank())
      
    # Fila Inferior (Mostramos el eje X)
    p3 <- ggplot(df_res, aes(x = Trimestre, y = Densidad)) +
      geom_col(fill = "#27ae60", alpha = 0.85, width = 0.5) + # Cambiado a barras
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Densidad Media") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_text(face="bold"))
      
    p4 <- ggplot(df_res, aes(x = Trimestre, y = Carga_Gen)) +
      geom_col(fill = "#d35400", alpha = 0.85, width = 0.5) +
      theme_minimal(base_size = 13) + labs(x = NULL, y = "Carga Media") + 
      theme(axis.title.y = element_text(face="bold", color="#000000"), axis.text.x = element_text(face="bold"))
      
    (p1 | p2) / (p3 | p4) + plot_annotation(title = "Medias de carga por Trimestre", theme = theme(plot.title = element_text(size = 16, face = "bold", hjust = 0.5, color="#000000")))
  })

  # 5. RADIOGRAFÍA DE LA SESIÓN (TEORÍA)
  output$grafica_sesion <- renderPlot({
    req(input$ana_sesion, input$ana_grupo)
    res_db <- tryCatch(dbGetQuery(con, sprintf("SELECT metricas_generales::text as met FROM sesion WHERE grupo_id = %s AND fecha = '%s' LIMIT 1", as.numeric(input$ana_grupo), input$ana_sesion)), error = function(e) data.frame())
    req(nrow(res_db) > 0)
    df_base <- parsear_series_sesion(res_db$met[1]); req(!is.null(df_base))
    
    p1 <- ggplot(df_base, aes(x = as.factor(Serie), y = Densidad)) +
      geom_line(aes(group = 1), color = "#2c3e50", size = 1.2) +
      geom_point(color = "#2c3e50", size = 3) +
      facet_grid(~ Bloque, scales = "free_x") +
      theme_minimal(base_size = 14) +
      labs(x = NULL, y = "Ratio T:D", title = "Radiografía Planificada por Serie") +
      theme(axis.text.x = element_blank(), strip.background = element_rect(fill = "#2c3e50"), strip.text = element_text(color = "white", face = "bold"), axis.title.y = element_text(color = "#2c3e50", face = "bold"))
      
    p2 <- ggplot(df_base, aes(x = as.factor(Serie), y = Carga)) +
      geom_col(aes(fill = Bloque), width = 0.6, alpha = 0.85, color = "black") +
      scale_fill_manual(values = c("Velocidad" = "#e20e0e", "Principal" = "#63db34")) +
      facet_grid(~ Bloque, scales = "free_x") +
      theme_minimal(base_size = 14) +
      labs(x = "Nº de Serie", y = "Carga por Serie") +
      theme(legend.position = "none", strip.background = element_blank(), strip.text = element_blank(), axis.title.y = element_text(color = "#2c3e50", face = "bold"))
      
    p1 / p2 + plot_layout(heights = c(1, 3))
  })

  # 6. RADIOGRAFÍA DE LA SESIÓN (ATLETA)
  output$grafica_sesion_atleta <- renderPlot({
    req(input$ana_sesion, input$ana_atleta)
    res_db <- tryCatch(dbGetQuery(con, sprintf("SELECT r.metricas_generales::text as met FROM resultados_sesion r JOIN sesion s ON r.sesion_id = s.sesion_id WHERE r.atleta_id = %s AND s.fecha = '%s' LIMIT 1", as.numeric(input$ana_atleta), input$ana_sesion)), error = function(e) data.frame())
    req(nrow(res_db) > 0)
    df_base <- parsear_series_sesion(res_db$met[1]); req(!is.null(df_base))
    
    p1 <- ggplot(df_base, aes(x = as.factor(Serie), y = Densidad)) +
      geom_line(aes(group = 1), color = "#2c3e50", size = 1.2) +
      geom_point(color = "#2c3e50", size = 3) +
      facet_grid(~ Bloque, scales = "free_x") +
      theme_minimal(base_size = 14) +
      labs(x = NULL, y = "Ratio T:D", title = "Radiografía REAL por Serie (Atleta)") +
      theme(axis.text.x = element_blank(), strip.background = element_rect(fill = "#d35400"), strip.text = element_text(color = "white", face = "bold"), axis.title.y = element_text(color = "#d35400", face = "bold"))
      
    p2 <- ggplot(df_base, aes(x = as.factor(Serie), y = Carga)) +
      geom_col(aes(fill = Bloque), width = 0.6, alpha = 0.85, color = "black") +
      scale_fill_manual(values = c("Velocidad" = "#f39c12", "Principal" = "#d35400")) +
      facet_grid(~ Bloque, scales = "free_x") +
      theme_minimal(base_size = 14) +
      labs(x = "Nº de Serie", y = "Carga REAL") +
      theme(legend.position = "none", strip.background = element_blank(), strip.text = element_blank(), axis.title.y = element_text(color = "#d35400", face = "bold"))
      
    p1 / p2 + plot_layout(heights = c(1, 3))
  })
}

shinyApp(ui, server)