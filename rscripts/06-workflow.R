## Setup --------------------------------------------
library(tidyverse)
library(patchwork)
library(scales)

## Cambia el default del tamaño de fuente 
theme_set(theme_linedraw(base_size = 25))

## Cambia el número de decimales para mostrar
options(digits = 4)

sin_lineas <- theme(panel.grid.major = element_blank(),
                    panel.grid.minor = element_blank())
color.itam  <- c("#00362b","#004a3b", "#00503f", "#006953", "#008367", "#009c7b", "#00b68f", NA)

sin_leyenda <- theme(legend.position = "none")
sin_ejes <- theme(axis.ticks = element_blank(), axis.text = element_blank())

## Librerias para modelacion bayesiana
library(cmdstanr)
library(posterior)
library(bayesplot)

tweets   <- read_csv("datos/response_times.csv")
tweets   <- tweets |>
  mutate(compania = author_id_y,
         fecha = created_at_x,
         anio  = lubridate::year(fecha),
         mes   = lubridate::month(fecha),
         dia   = lubridate::day(fecha))

reclamos <- tweets |>
  select(anio, mes, dia, compania, response_time) |>
  filter(anio == 2017, mes %in% c(10, 11),
         !(compania %in% c("AmericanAir", "Delta", "SouthwestAir"))) |>
  group_by(anio, mes, dia, compania) |>
  summarise(atendidos = n(),
            respuesta = mean(response_time)) |>
  mutate(compania = factor(compania)) |> 
  ungroup()

reclamos |>
  ggplot(aes(atendidos)) +
  geom_histogram()

reclamos |>
ungroup()|>
  summarise(reclamos = mean(atendidos)) |>
  as.data.frame()

modelos_files <- "modelos/compilados/reclamaciones"
ruta <- file.path("modelos/reclamaciones/modelo-poisson.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

ajustar_modelo <- function(modelo, datos, iter_sampling = 1000, iter_warmup = 1000, seed = 2210){ 
  ajuste <- modelo$sample(data = datos, 
                          seed = seed,
                          iter_sampling = iter_sampling, 
                          iter_warmup = iter_sampling,
                          refresh = 0, 
                          show_messages = FALSE)
  ajuste
}

data_list <- list(N = nrow(reclamos), y = reclamos$atendidos)
previa <- modelo$sample(data = list(N = 0, y = c()), refresh = 0)
posterior <- modelo$sample(data = data_list, refresh = 0)

posterior$summary() |> as.data.frame()

simulaciones <- previa$draws(format = "df") |>
  mutate(dist = "previa") |>
  rbind(posterior$draws(format = "df") |>
        mutate(dist = "posterior"))

simulaciones |>
  ggplot(aes(lambda, fill = dist)) +
  geom_histogram(position = "identity", alpha = .6) +
  ggtitle("Simulaciones de parámetro desconocido")

simulaciones |>
  as_tibble() |>
  mutate(y_tilde = map_dbl(lambda, function(x){
    rpois(1, x)
  })) |>
  ggplot(aes(y_tilde, fill = dist)) +
  geom_histogram(position = "identity", alpha = .6) +
  ggtitle("Simulaciones de predictivas")

g1 <- simulaciones |>
  as_tibble() |>
  mutate(y_tilde = map_dbl(lambda, function(x){
    rpois(1, x)
  })) |>
  ggplot(aes(y_tilde, fill = dist)) +
  geom_histogram(position = "identity", alpha = .6) +
  xlab("atendidos*") +
  ggtitle("Simulaciones de predictivas") + sin_lineas +
  xlim(0, 300)

g2 <- reclamos |>
  ggplot(aes(atendidos)) +
  geom_histogram(position = "identity", alpha = .6) +
  ggtitle("Histograma datos") + sin_lineas + xlim(0, 300)

g2 + g1

reclamos |>
  summarise(promedio = mean(atendidos),
            varianza = var(atendidos)) |>
as.data.frame()

modelos_files <- "modelos/compilados/reclamaciones"
ruta <- file.path("modelos/reclamaciones/modelo-negbinom.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

data_list <- list(N = nrow(reclamos), y = reclamos$atendidos)
previa <- modelo$sample(data = list(N = 0, y = c()), refresh = 0)
posterior <- modelo$sample(data = data_list, refresh = 0, seed = 108727)

posterior$summary() |> as.data.frame()

modelos_files <- "modelos/compilados/reclamaciones"
ruta <- file.path("modelos/reclamaciones/modelo-negbinom-log.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

data_list <- list(N = nrow(reclamos), y = reclamos$atendidos)
previa <- modelo$sample(data = list(N = 0, y = c()), refresh = 0)
posterior <- modelo$sample(data = data_list, refresh = 0)

posterior$summary() |> as.data.frame()

g1 <- mcmc_trace(posterior$draws(), pars = c("log_lambda", "phi"))
g2 <- mcmc_hist(posterior$draws(), pars = c("log_lambda", "phi"))

g1 / g2

g1 <- previa$draws(format = "df") |>
  rbind(posterior$draws(format = "df")) |>
  as_tibble() |>
  mutate(dist = rep(c("previa", "posterior"), each = 4000)) |>
  ggplot(aes(y_tilde, fill = dist)) +
  geom_histogram(position = "identity", alpha = .4) +
  sin_lineas + xlim(0, 300) +
  ggtitle("Simulaciones de predictivas")

g2 <- reclamos |>
  ggplot(aes(atendidos)) +
  geom_histogram(position = "identity", alpha = .6) +
  ggtitle("Histograma datos") + sin_lineas + xlim(0, 300)

g2 + g1

reclamos |>
  group_by(compania) |>
  summarise(promedio = mean(atendidos),
            varianza = var(atendidos)) |>
  as.data.frame()

modelos_files <- "modelos/compilados/reclamaciones"
ruta <- file.path("modelos/reclamaciones/modelo-negbinom-jerarquico.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

data_list <- list(N = nrow(reclamos),
                  y = reclamos$atendidos,
                   compania = as.numeric(reclamos$compania))
posterior <- modelo$sample(data = data_list, refresh = 0)

posterior$summary() |> as.data.frame()



datos <- read_delim("datos/golf.csv", delim = " ")
datos <- datos |> 
  mutate(x = round(30.48  * x, 0), 
         se = sqrt((y/n)*(1-y/n)/n))

g_datos <- datos |> 
  ggplot(aes(x = x, y = y/n)) + 
    geom_linerange(aes(ymin = y/n - 2 * se, ymax = y/n + 2*se)) + 
    geom_point(colour = "steelblue", alpha = 1.) + 
    ylim(c(0,1)) + xlab("Distancia (cm)") + ylab("Tasa de éxito") + 
    ggtitle("Datos sobre putts en golf profesional") + sin_lineas

g_datos

modelos_files <- "modelos/compilados/golf"
ruta <- file.path("modelos/golf/modelo-logistico.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

ajustar_modelo <- function(modelo, datos, iter_sampling = 1000, iter_warmup = 1000, seed = 2210){ 
  ajuste <- modelo$sample(data = datos, 
                          seed = seed,
                          iter_sampling = iter_sampling, 
                          iter_warmup = iter_sampling,
                          refresh = 0, 
                          show_messages = FALSE)
  ajuste
}

data_list <- c(datos, list("J" = nrow(datos)))
ajuste <- ajustar_modelo(modelo, data_list)

ajuste$summary() |> as.data.frame()

muestras <- tibble(posterior::as_draws_df(ajuste$draws(c("a", "b"))))
muestras |>
  pivot_longer(cols = c(a, b), names_to = 'parameter') |> 
  mutate(Chain = as.factor(.chain)) |> 
  ggplot(aes(x = .iteration, y = value)) + 
  geom_line(aes(group = .chain, color = Chain)) + 
  facet_wrap(~parameter, ncol = 1, scales = 'free', strip.position="right") + 
  scale_color_viridis_d(option = 'plasma')+ sin_lineas

params_map <- modelo$optimize(data = data_list, seed = 108)
params_map <- params_map$summary() |>
  pivot_wider(values_from = estimate, names_from = variable)
params_map |> as.data.frame()

muestras |> 
  ggplot(aes(x = a, y = b)) + 
  geom_point() + 
  geom_point(data = params_map, aes(x = a, y = b),
             color = 'salmon', shape = 4, stroke = 2) + 
  ggtitle('Muestras de la posterior')+ sin_lineas

logit <- qlogis
invlogit <- plogis

modelo_logistico <- function(a, b){
  x <- seq(0, 1.1 * max(datos$x), length.out = 50)
  tibble(x = x, y = invlogit(a *x + b))
}

curvas_regresion <- muestras |> 
  mutate(curva = map2(a, b, modelo_logistico)) |> 
  select(-a, -b) |> 
  unnest(curva) |> 
  group_by(x) |> 
  summarise(mediana = median(y), 
            q_low = quantile(y, .005), 
            q_hi = quantile(y, .995), 
            .groups = 'drop')

g_logistico <- datos |> 
  ggplot(aes(x = x, y = y/n)) + 
  geom_linerange(aes(ymin = y/n - 2 * se, ymax = y/n + 2*se)) + 
  geom_point(colour = "steelblue", alpha = 1.) + 
  geom_line(data = curvas_regresion, aes(x = x, y = mediana)) +
  geom_ribbon(data = curvas_regresion, aes(x = x, ymin = q_low, ymax = q_hi), 
              alpha = .2, inherit.aes = FALSE) +
  ylim(c(0,1)) + xlab("Distancia (cm)") + ylab("Tasa de éxito") + 
  ggtitle("Regresion logística ajustada")+ sin_lineas

muestras_logistico <- muestras
g_logistico

radios <- tibble(pelota = (1.68/2 * 2.54) |> round(1), 
                  hoyo  = (4.25/2 * 2.54) |> round(1))
radios |> as.data.frame()

tibble(x = seq(10, 1500, 1)) |> 
  mutate(theta = (180 / pi) * atan(3.3 / x)) |> 
ggplot(aes(x, theta)) + geom_line() +
  xlab("Distancia (cm)") +
  ylab(expression(paste("Desviación máxima |", theta,"|"))) +
  labs(subtitle = "Desviación máxima permitida para tener éxito a distintas distancias") +
  scale_y_log10()+ sin_lineas

curva_angulo <- function(sigma){
  x <- seq(0, 650, by = .5)
  R.diff <- radios |> summarise(diff = hoyo - pelota) |> pull(diff)
  tibble(x = x, y = 2 * pnorm( (180/pi) * atan(R.diff/x)/sigma) - 1)
}

tibble(sigma = 2**seq(0,5)) |> 
  mutate(curva = map(sigma, curva_angulo), 
         Sigma = as.factor(sigma)) |> 
  unnest(curva) |> 
  ggplot(aes(x = x, y = y)) + 
    geom_line(aes(group = sigma, color = Sigma)) + 
    scale_color_viridis_d() + ylim(c(0,1)) + xlab("Distancia (cm)") + ylab("Probabilidad de éxito") + 
  ggtitle(expression(paste("Probabilidad de éxito para diferentes valores de ",
                           sigma," (en grados ", ~degree, ").")), )+ sin_lineas +
  theme(plot.title = element_text(size = 15))

simula_tiros <- function(sigma){
  distancia  <- 1
  n_muestras <- 250
  angulos_tiro <- (pi/180) * rnorm(n_muestras, 0, sigma)
  tibble(x = distancia * cos(angulos_tiro), 
         y = distancia * sin(angulos_tiro))
}

tibble(sigma_grados = c(1, 8, 32, 64)) |> 
  mutate(tiros = map(sigma_grados, simula_tiros)) |> 
  unnest(tiros) |> 
  ggplot(aes(x = x, y = y)) + 
    geom_point() +
    geom_segment(aes(x = 0, y = 0, xend = x, yend = y), alpha = .1) + 
    geom_point(aes(x = 0, y = 0), color = 'red') + 
    facet_wrap(~sigma_grados, ncol = 4) + 
    ylab("") + xlab("") + ggtitle("Posiciones finales de tiro")+ sin_lineas +
  coord_equal()

data_list$r = radios$pelota
data_list$R = radios$hoyo

ruta <- file.path("modelos/golf/modelo-angulo.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

ajuste <- ajustar_modelo(modelo, data_list)
ajuste$summary() |> as.data.frame()

muestras <- tibble(posterior::as_draws_df(ajuste$draws(c("sigma", "sigma_degrees"))))

muestras |> 
  select(-sigma_degrees) |> 
  pivot_longer(cols = c(sigma), names_to = 'parameter') |> 
  mutate(Chain = as.factor(.chain)) |> 
  ggplot(aes(x = .iteration, y = value)) + 
    geom_line(aes(group = .chain, color = Chain)) + 
    facet_wrap(~parameter, ncol = 1, scales = 'free', strip.position="right") + 
  scale_color_viridis_d(option = 'plasma')+ sin_lineas

modelo_angulo <- function(sigma_radianes){
  x <- seq(0, 1.1 * max(datos$x), length.out = 50)
  R.diff <- radios |> summarise(diff = hoyo - pelota) |> pull(diff)
  tibble(x = x, y = 2 * pnorm( atan(R.diff/x)/sigma_radianes) - 1)
}

curvas_regresion <- muestras |> 
  mutate(curva = map(sigma, modelo_angulo)) |> 
  select(-sigma_degrees, -sigma) |> 
  unnest(curva) |> 
  group_by(x) |> 
  summarise(mediana = median(y), 
            q_low = quantile(y, .005), 
            q_hi = quantile(y, .995), 
            .groups = 'drop')

g_angulo <- datos |> 
  ggplot(aes(x = x, y = y/n)) + 
    geom_linerange(aes(ymin = y/n - 2 * se, ymax = y/n + 2*se)) + 
    geom_point(colour = "steelblue", alpha = 1.) + 
    geom_line(data = curvas_regresion, aes(x = x, y = mediana)) +
    geom_ribbon(data = curvas_regresion, aes(x = x, ymin = q_low, ymax = q_hi), 
                alpha = .2, inherit.aes = FALSE) +
    ylim(c(0,1)) + xlab("Distancia (cm)") + ylab("Tasa de éxito") + 
    ggtitle("Modelo con ángulo de tiro")+ sin_lineas

g_logistico + g_angulo

datos_grande <- read_delim("datos/golf_grande.csv", delim = "\t")
datos_grande <- datos_grande |> 
  mutate(x = dis * 30.48, n = count, y = exitos, se = sqrt((y/n)*(1-y/n)/n), fuente = "Nuevos") |> 
  select(x, n, y, se, fuente)

datos <- rbind(datos |> mutate(fuente = "Original"), datos_grande)
datos <- datos |> mutate(fuente = as.factor(fuente))

curvas_regresion <- muestras |> 
  mutate(curva = map(sigma, modelo_angulo)) |> 
  select(-sigma_degrees, -sigma) |> 
  unnest(curva) |> 
  group_by(x) |> 
  summarise(mediana = median(y), 
            q_low = quantile(y, .005), 
            q_hi = quantile(y, .995), 
            .groups = 'drop')

datos |> 
  ggplot(aes(x = x, y = y/n)) + 
    geom_linerange(aes(ymin = y/n - 2 * se, ymax = y/n + 2 * se)) + 
    geom_point(aes(colour = fuente), alpha = 1.) +
    geom_line(data = curvas_regresion, aes(x = x, y = mediana)) +
    geom_ribbon(data = curvas_regresion, aes(x = x, ymin = q_low, ymax = q_hi),
                alpha = .2, inherit.aes = FALSE) +
    ylim(c(0,1)) + xlab("Distancia (cm)") + ylab("Tasa de éxito") +
    ggtitle("Modelo con ángulo de tiro")+ sin_lineas

data_new <- list(x = datos$x, n = datos$n, y = datos$y, J = nrow(datos), 
                 r = radios$pelota, R = radios$hoyo, 
                 distance_tolerance = 4.5 * 30.48,# 145,
                 overshot = 30.48)

ruta <- file.path("modelos/golf/angulo-fuerza.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

ajuste <- ajustar_modelo(modelo, data_new, seed = 108727)
ajuste$summary(c("sigma_angle", "sigma_degrees", "sigma_force")) |> as.data.frame()

modelo_angulo_fuerza <- function(sigma_radianes, sigma_fuerza){
  x <- seq(0, 1.1 * max(datos$x), length.out = 50)
  R.diff <- radios |> summarise(diff = hoyo - pelota) |> pull(diff)
  tibble(x = x, 
         p_angulo = 2 * pnorm( atan(R.diff/x)/sigma_radianes) - 1, 
         p_fuerza = pnorm((data_new$distance_tolerance - data_new$overshot) /
                          ((x + data_new$overshot)*sigma_fuerza)) - 
           pnorm((- data_new$overshot) / ((x + data_new$overshot)*sigma_fuerza)), 
         y = p_angulo * p_fuerza) |> 
    select(x, y)
}

muestras <- tibble(posterior::as_draws_df(ajuste$draws(c("sigma_angle", "sigma_force"))))

curvas_regresion <- muestras |> 
  mutate(curva = map2(sigma_angle, sigma_force, modelo_angulo_fuerza)) |> 
  select(-sigma_angle, -sigma_force) |> 
  unnest(curva) |> 
  group_by(x) |> 
  summarise(mediana = median(y), 
            q_low = quantile(y, .005), 
            q_hi = quantile(y, .995), 
            .groups = 'drop')

datos |> 
  ggplot(aes(x = x, y = y/n)) + 
    geom_linerange(aes(ymin = y/n - 2 * se, ymax = y/n + 2 * se)) + 
    geom_point(aes(colour = fuente), alpha = 1.) +
    geom_line(data = curvas_regresion, aes(x = x, y = mediana)) +
  geom_ribbon(data = curvas_regresion, aes(x = x, ymin = q_low, ymax = q_hi),
                alpha = .2, inherit.aes = FALSE) +
    ylim(c(0,1)) + xlab("Distancia (cm)") + ylab("Tasa de éxito") +
  ggtitle("Modelo con ángulo de tiro y fuerza")+ sin_lineas

muestras <- tibble(posterior::as_draws_df(ajuste$draws(c("residual"))))
medias <- muestras |> 
  pivot_longer(cols = starts_with("residual"), names_to = 'parameters', values_to = 'residuals') |> 
  group_by(parameters) |> 
  summarise(media = mean(residuals), 
            q_lo = quantile(residuals, 0.05),
            q_hi = quantile(residuals, 0.95), groups = 'drop') |> 
  mutate(cadena = str_replace_all(parameters, "\\[|\\]", "_")) |> 
  separate(cadena, into = c("sufijo", "variable"), sep = "_", convert = TRUE) |> 
  select(media, variable, q_lo, q_hi)

datos |> 
  mutate(variable = seq(1, nrow(datos))) |> 
  full_join(medias) |> 
  ggplot(aes(x = x, y = media)) + 
  geom_linerange(aes(x = x, ymin = q_lo, ymax = q_hi)) + 
  geom_point(aes(color = fuente)) + 
  geom_hline(yintercept = 0, linetype = 'dashed') + 
  ylab('Residuales del modelo ajustado') + 
  xlab('Distancia (cm)') + 
  ggtitle("Modelo con angulo y fuerza de tiro.")+ sin_lineas

ruta <- file.path("modelos/golf/fuerza-normal-plano.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

ajuste <- ajustar_modelo(modelo, data_new, iter_sampling = 1000, seed = 108727)
ajuste$summary(c("sigma_angle", "sigma_obs", "sigma_force")) |> as.data.frame()

ruta <- file.path("modelos/golf/angulo-fuerza-normal.stan")
modelo <- cmdstan_model(ruta, dir = modelos_files)

ajuste <- ajustar_modelo(modelo, data_new, iter_sampling = 4000, seed = 108727)
ajuste$summary(c("sigma_angle", "sigma_degrees", "sigma_force", "sigma_obs")) |> as.data.frame()

color_scheme_set("darkgray")
muestras_sigma <- ajuste$draws(c("sigma_force", "sigma_obs", "sigma_degrees"))
mcmc_pairs(muestras_sigma, off_diag_fun = "hex", grid_args = list(size = 0))

muestras <- tibble(posterior::as_draws_df(ajuste$draws(c("residual"))))
medias <- muestras |> 
  pivot_longer(cols = starts_with("residual"), names_to = 'parameters', values_to = 'residuals') |> 
  group_by(parameters) |> 
  summarise(media = mean(residuals), 
            q_lo = quantile(residuals, 0.05),
            q_hi = quantile(residuals, 0.95), groups = 'drop') |> 
  mutate(cadena = str_replace_all(parameters, "\\[|\\]", "_")) |> 
  separate(cadena, into = c("sufijo", "variable"), sep = "_", convert = TRUE) |> 
  select(media, variable, q_lo, q_hi)

datos |> 
  mutate(variable = seq(1, nrow(datos))) |> 
  full_join(medias) |> 
  ggplot(aes(x = x, y = media)) + 
    geom_linerange(aes(x = x, ymin = q_lo, ymax = q_hi)) + 
    geom_point(aes(color = fuente)) + 
    geom_hline(yintercept = 0, linetype = 'dashed') + 
    ylab('Residuales del modelo ajustado') + 
    xlab('Distancia (cm)') + 
  ggtitle("Modelo con angulo y fuerza de tiro.")+ sin_lineas
