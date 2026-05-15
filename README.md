# Diario_Entrenamientos

## 🎯 Descripción y objetivos del proyecto

Este proyecto tiene por objetivo general **facilitar la planificación** del entrenamiento deportivo a través de varios subojetivos:

- Hacer una **interfaz interactiva que reduzca el tiempo** empleado en planificar (en Ciencias del Deporte en la actualidad se trabja sobre todo con Excel).
-  Permitir que los atletas puedan **ver el entrenamiento de cada día e introducir sus resultados**. De esta forma, se puede llevar un **control del entrenamiento** de cada deportista.
-  A través de gráficos, complementar la **comprensión del entrenamiento** para los corredores. Las gráficas son también interesantes para el entrenador, ya que le permite **comprobar de forma rápida si las cargas están bien ajustadas** para los objetivos de cada semana.

## ⚒️ Estructura del dashboard y funcionalidades implementadas

### Estructura

El dashboard tiene cuatro pestañas:

1. **Planificación**: En esta pestaña el entrenador define la planificación. En los filtros puede elegir a qué temporada (año natural) y a qué grupo (CNP, Policía Municipal, Guardia Civil o Militar) pertenece dicha planificación.

Si en la base de datos (BBDD) ya existe una planificación para esa temporada y ese grupo, se puede cargar. En caso contrario, se puede crear desde 0.

Con el botón "Sincronizar" los datos pueden añadirse (o actualizarse si ya existían) en la BBDD.

Dentro de cada macrociclo (trimestre), se pueden añadir o eliminar microciclos (semanas) de cada uno de los mesociclos (meses). Dentro de cada microciclo se puede escribir el objetivo de cada sesión.

En el botón del engranaje puede añadirse la estructura específica de cada sesión. Al darle a "Guardar" los datos se guardan en memoria. Al pulsar en el botón "Sincronizar" los datos de las sesiones también se guardan en su correspondiente tabla de la BBDD.

2. **Resultados atletas**: En esta pestaña los atletas pueden escribir las marcas que han hecho en cada una de las series del entrenamiento (pueden elegir su nombre y la sesión que quieren añadir en los filtros), la recuperación que han tenido y su percepción del esfuerzo (RPE). Al pulsar en el botón "Guardar Resultados" los datos se guardan en su correspondiente tabla de la BBDD (se añaden o se actualizan). Al igual que en la pestaña anterior, si ya había datos para un atleta en una sesión, se cargan automáticamente en la pestaña.

3. **Perfiles atletas**: En esta hoja aparece el perfil del atleta que se seleccione en los filtros. Aparece su mejor marca en la prueba objetivo de su oposición (1000 para CNP, 800 para Policía Municipal y 2000 para Guardia Civil y Militar) y su ritmo de referencia (se explica en el siguiente apartado). Los datos de esta pestaña se pueden cargar de la BBDD si ya existen y se pueden añadir o actualizar pulsando el botón verde.

4. **Análisis**: En esta pestaña se presentan las visuaizaciones del año, del macrociclo, del mesociclo, del microciclo y dos de la sesión. Los filtros permiten localizar una temporada, grupo o sesión o atleta concreta (**¿alguna mas?**).

Para las visualizaciones se han calculado métricas como el volumen, la intensidad, la densidad y la carga del entrenamiento (se explican en el siguiente apartado). Para las generales se han utilizado los datos del diseño de la sesión (primera pestaña). Para las visualizaciones de los atletas se han utilizado los datos de su perfil y de sus resultados de entrenamiento.

### Funcionalidades

### BBDD

## 📚 Descripción de los datos utilizados y su orgien

Los datos utilizados son de elaboración propia de la planificación deportiva para las pruebas de acceso al Cuerpo Nacional de Policía, Policía Municipal, Guardia Civil y Militar.

Cada planificación anual se divide en cuatro trimestres o **macrociclos** que tienen la misma estructura: 
- Un **mesociclo básico** (es el mesociclo que trabaja los contenidos más alejados de la prueba).
- Un **mesociclo específico** (las cargas se acercan a la situación real de la prueba).
- Un **mesociclo competitivo** (la mayoría de cargas son muy similares a las características de la prueba y se hace una puesta apunto).
Los mesociclos suelen durar entre 3 y 5 semanas.

Cada mesociclo se compone de microcilos que duran una semana. En función de los objetivos del **microciclo** se establecen los siguientes tipos:
- **Recuperación**: Pensado para hacer recuperación activa.
- **Ajuste**: Es un microciclo con cargas medias entre el microcilo de recuperación y el de carga.
- **Carga**: En este microciclo se hacen entrenamientos enfocados en potenciar capacidades concretas.
- **Impacto**: Este microciclo se usa cuando se quieren introducir nuevas capacidades en la planificación.
- **Aproximación**: En este microciclo las cargas buscan especificidad sin agotar.
- **Competición**: Es la semana correspondiente a la competición.

Cada microciclo se compone de dos **sesiones** cuyos objetivos dependen de la capacidad física que se quiera trabajar. Pueden ser:
- Potencia Aláctica (PALA)
- Capacidad Aláctica (CALA)
- Potencia Láctica (PLA)
- Capacidad (CLA)
- Potencia Aeróbica (PAE)
- Capacidad Aeróbica (CAE)
- Aeróbico Intensidad (AEI)
- Aeróbico Medio (AEM)
- Aeróbico Ligero (AEL)

Cada sesión se compone de un calentamiento, una parte de velocidad y una parte principal de series más largas.
Las cargas de entrenamiento se miden con el **volumen** de cada serie, el volumen total de la sesión, la **intensidad** de las series (en esta planificación se mide relativamente con el ritmo de referencia*) y la **densidad** del entrenamiento (el ratio entre tiempo de trabajo y tiempo de descanso). De la multiplicación del volumen con la intensidad se obtiene la **carga**.

*El ritmo de referencia se calcula con respecto a la prueba objetivo. Por ejemplo, para el CNP se debe preparar un 1000. Para un deportista que haga un 1000 en 3'00", la media de cada 100m son 19". Ese es por tanto el ritmo de referencia. Si en una serie de 400 el ritmo fuera +2" del 1000 (2 segundos más lento que el ritmo de referencia para el 1000), sería hacer un 400 a 21" cada 100 metros, en total 1'24". Si después de esta serie el descanso fuera de 1'30", el ratio trabajo-descanso seria aproximadamente de 1:1.

## 🌐 Enlace a ShinyApps

## 📊 Explicación de los fundamentos de la visualización de datos aplicados en el dashboard

## 🧠 Conclusiones y posibles mejoras futuras
