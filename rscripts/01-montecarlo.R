## Setup --------------------------------------------------

library(tidyverse)
library(patchwork)
library(scales)
## Cambia el default del tamaño de fuente 
theme_set(theme_linedraw(base_size = 25))

## Cambia el número de decimales para mostrar
options(digits = 2)

sin_lineas <- theme(panel.grid.major = element_blank(),
                    panel.grid.minor = element_blank())
color.itam  <- c("#00362b","#004a3b", "#00503f", "#006953", "#008367", "#009c7b", "#00b68f", NA)

sin_lineas <- theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank())
sin_leyenda <- theme(legend.position = "none")
sin_ejes <- theme(axis.ticks = element_blank(), 
      axis.text = element_blank())

## Ejemplo de integracion numerica -----------------------

grid.n          <- 11                 # Número de celdas 
grid.size       <- 6/(grid.n+1)       # Tamaño de celdas en el intervalo [-3, 3]
norm.cuadrature <- tibble(x = seq(-3, 3, by = grid.size), y = dnorm(x) )


norm.density <- tibble(x = seq(-5, 5, by = .01), 
       y = dnorm(x) )

norm.cuadrature |>
  ggplot(aes(x=x + grid.size/2, y=y)) + 
  geom_area(data = norm.density, aes(x = x, y = y), fill = 'lightblue') + 
  geom_bar(stat="identity", alpha = .3) + 
  geom_bar(aes(x = x + grid.size/2, y = -0.01), fill = 'black', stat="identity") + 
  sin_lineas + xlab('x') + ylab("density") + 
  annotate('text', label = expression(Delta~u[n]),
           x = .01 + 5 * grid.size/2, y = -.02, size = 12) + 
  annotate('text', label = expression(f(u[n]) ),
           x = .01 + 9 * grid.size/2, y = dnorm(.01 + 4 * grid.size/2), size = 12) + 
  annotate('text', label = expression(f(u[n]) * Delta~u[n]), 
           x = .01 + 5 * grid.size/2, y = dnorm(.01 + 4 * grid.size/2)/2, 
           angle = -90, alpha = .7, size = 12)

grid.n          <- 101                 # Número de celdas 
grid.size       <- 6/(grid.n+1)       # Tamaño de celdas en el intervalo [-3, 3]
norm.cuadrature <- tibble(x = seq(-3, 3, by = grid.size), y = dnorm(x) )

norm.cuadrature |>
    ggplot(aes(x=x + grid.size/2, y=y)) + 
    geom_area(data = norm.density, aes(x = x, y = y), fill = 'lightblue') + 
    geom_bar(stat="identity", alpha = .3) + 
    geom_bar(aes(x = x + grid.size/2, y = -0.01), fill = 'black', stat="identity") + 
    sin_lineas + xlab('x') + ylab("density") + 
    annotate('text', label = expression(Delta~u[n]),
             x = .01 + 5 * grid.size/2, y = -.02, size = 12) + 
    annotate('text', label = expression(f(u[n]) ),
             x = .01 + 9 * grid.size/2, y = dnorm(.01 + 4 * grid.size/2), size = 12) + 
    annotate('text', label = expression(f(u[n]) * Delta~u[n]), 
             x = .01 + 5 * grid.size/2, y = dnorm(.01 + 4 * grid.size/2)/2, 
             angle = -90, alpha = .7, size = 12)

crear_log_post <- function(n, k){
  function(theta){
    verosim <- k * log(theta) + (n - k) * log(1 - theta)
    inicial <- log(theta)
    verosim + inicial
  }
}

# observamos 3 éxitos en 4 pruebas:
log_post <- crear_log_post(4, 3)
prob_post <- function(x) { exp(log_post(x))}
# integramos numéricamente
p_x <- integrate(prob_post, lower = 0, upper = 1, subdivisions = 100L)
p_x

media_funcion <- function(theta){
  theta * prob_post(theta) / p_x$value
}
integral_media <- integrate(media_funcion,
                            lower = 0, upper = 1,
                            subdivisions = 100L)
media_post <- integral_media$value 
c(Numerico = media_post, Analitico = 5/(2+5))

canvas <- ggplot(faithful, aes(x = eruptions, y = waiting)) +
     xlim(0.5, 6) +
     ylim(40, 110)

    grid.size <- 10 - 1

    mesh <- expand.grid(x = seq(0.5, 6, by = (6-.5)/grid.size),
                        y = seq(40, 110, by = (110-40)/grid.size))

  g1 <- canvas +
      geom_density_2d_filled(aes(alpha = ..level..), bins = 8) +
      scale_fill_manual(values = rev(color.itam)) + 
      sin_lineas + theme(legend.position = "none") +
      geom_point(data = mesh, aes(x = x, y = y)) + 
      annotate("rect", xmin = .5 + 5 * (6-.5)/grid.size, 
                xmax = .5 + 6 * (6-.5)/grid.size, 
                ymin = 40 + 3 * (110-40)/grid.size, 
                ymax = 40 + 4 * (110-40)/grid.size,
                linestyle = 'dashed', 
               fill = 'salmon', alpha = .4) + ylab("") + xlab("") + 
      annotate('text', x = .5 + 5.5 * (6-.5)/grid.size, 
                       y = 40 + 3.5 * (110-40)/grid.size, 
               label = expression(u[n]), color = 'red', size = 15) +
        theme(axis.ticks = element_blank(), 
            axis.text = element_blank())


  g2 <- canvas + 
      stat_bin2d(aes(fill = after_stat(density)), binwidth = c((6-.5)/grid.size, (110-40)/grid.size)) +
      sin_lineas + theme(legend.position = "none") +
      theme(axis.ticks = element_blank(), 
              axis.text = element_blank()) +
      scale_fill_distiller(palette = "Greens", direction = 1) + 
      sin_lineas + theme(legend.position = "none") +
      ylab("") + xlab("")

  g3 <- canvas + 
      stat_bin2d(aes(fill = after_stat(density)), binwidth = c((6-.5)/25, (110-40)/25)) +
      sin_lineas + theme(legend.position = "none") +
      theme(axis.ticks = element_blank(), 
              axis.text = element_blank()) +
      scale_fill_distiller(palette = "Greens", direction = 1) + 
      sin_lineas + theme(legend.position = "none") +
      ylab("") + xlab("")

g1 + g2 + g3

## Integración Monte Carlo ----------------------------------- 
genera_dardos <- function(n = 100){
    tibble(x1 = runif(n, min = -1, max = 1), 
           x2 = runif(n, min = -1, max = 1)) %>% 
      mutate(resultado = ifelse(x1**2 + x2**2 <= 1., 1., 0.))
  }

  dardos <- tibble(n = seq(2,5)) %>% 
    mutate(datos = map(10**n, genera_dardos)) %>% 
    unnest() 

  dardos %>% 
    ggplot(aes(x = x1, y = x2)) + 
      geom_point(aes(color = factor(resultado))) + 
      facet_wrap(~n, nrow = 1) +  
    sin_lineas + sin_ejes + sin_leyenda + coord_equal()

dardos |>
  group_by(n) |>
  summarise(aprox = 4 * mean(resultado)) |>
  as.data.frame()

set.seed(1087)

genera_dardos(n = 2**16) %>% 
  mutate(n = seq(1, 2**16), 
         approx = cummean(resultado) * 4) %>% 
  ggplot(aes(x = n, y = approx)) + 
    geom_line() + 
    geom_hline(yintercept = pi, linetype = 'dashed') + 
    scale_x_continuous(trans='log10', 
                       labels = trans_format("log10", math_format(10^.x))) + 
  ylab('Aproximación') + xlab("Muestras") + sin_lineas

### Ejemplo proporciones ------------------

theta <- rbeta(10000, 5, 2)
media_post <- mean(theta)
momento_2_post <- mean(theta^2)
c(mu_1 = media_post, mu_2 = momento_2_post)

mean(exp(theta) > 2)

### Ejemplo helados -------------------------

datos <- tibble(
  sabor = c("fresa", "limon", "mango", "guanabana"),
  n = c(50, 45, 51, 50), gusto = c(36, 35, 42, 29)) %>% 
  mutate(prop_gust = gusto / n)

datos |>
as.data.frame()

datos <- datos |>
  mutate(a_post = gusto + 2,
         b_post = n - gusto + 1,
         media_post = a_post/(a_post + b_post))
datos |>
  as.data.frame()

modelo_beta <- function(params, n = 5000){
  rbeta(n, params$alpha, params$beta)
}

## Generamos muestras de la posterior
paletas <- datos |>
  mutate(alpha = a_post, beta = b_post) |>
  nest(params.posterior = c(alpha, beta)) |>
  mutate(muestras.posterior = map(params.posterior, modelo_beta)) |>
  select(sabor, muestras.posterior)

paletas |>
  unnest(muestras.posterior) |>
  ggplot(aes(muestras.posterior)) +
  geom_histogram(aes(fill = sabor), position = "identity" ) +
  sin_lineas

## Utilizamos el metodo Monte Carlo para aproximar la integral. 
paletas |>
  unnest(muestras.posterior) |>
  mutate(id = rep(seq(1, 5000), 4)) |> group_by(id) |>
  summarise(favorito = sabor[which.max(muestras.posterior)]) |>
  group_by(favorito) |> tally() |>
  mutate(prop = n/sum(n)) |>
  as.data.frame()

crea_mezcla <- function(weights){
    function(x){
      weights$w1 * dnorm(x, mean = -1.5, sd = .5) +
        weights$w2 * dnorm(x, mean = 1.5, sd = .7)
    }
  }
objetivo <- crea_mezcla(list(w1 = .6, w2 = .4))

muestras_mezcla <- function(id){
  n <- 100
  tibble(u = runif(n)) |>
    mutate(muestras = ifelse(u <= .6,
                             rnorm(1, -1.5, sd = .5),
                             rnorm(1,  1.5, sd = .7))) |>
    pull(muestras)
}

muestras.mezcla <- tibble(id = 1:1000) |>
  mutate(muestras  = map(id, muestras_mezcla)) |>
  unnest(muestras) |>
  group_by(id) |>
  summarise(estimate = mean(muestras))

g0 <- muestras.mezcla |>
  ggplot(aes(estimate)) +
  geom_histogram() +
  geom_vline(xintercept = -1.5 * .6 + 1.5 * .4, lty = 2, color = 'red') +
  geom_vline(xintercept = mean(muestras.mezcla$estimate), lty = 2, color = 'steelblue') +
  xlim(-1, 1) +
  ggtitle("Objetivo")

muestras_uniforme <- function(id){
  n <- 100
  runif(n, -5, 5)
}

muestras.uniforme <- tibble(id = 1:1000) |>
  mutate(muestras  = map(id, muestras_uniforme)) |>
  unnest(muestras) |>
  mutate(pix = objetivo(muestras),
         gx  = dunif(muestras, -5, 5),
         wx  = pix/gx) |>
  group_by(id) |>
  summarise(estimate = sum(muestras * wx)/sum(wx))

g1 <- muestras.uniforme |>
  ggplot(aes(estimate)) +
  geom_histogram() +
  geom_vline(xintercept = -1.5 * .6 + 1.5 * .4, lty = 2, color = 'red') +
  geom_vline(xintercept = mean(muestras.uniforme$estimate), lty = 2, color = 'steelblue') +
  xlim(-1, 1) +
  ggtitle("Uniforme(-5,5)")

muestras_importancia <- function(id){
  n <- 100
  rnorm(n, 0, sd = 1)
}  

muestras.normal  <- tibble(id = 1:1000) |>
  mutate(muestras  = map(id, muestras_importancia)) |>
  unnest(muestras) |>
  mutate(pix = objetivo(muestras),
         gx  = dnorm(muestras, 0, sd = 1),
         wx  = pix/gx) |>
  group_by(id) |>
  summarise(estimate = sum(muestras * wx)/sum(wx))

g2  <- muestras.normal |> ggplot(aes(estimate)) +
  geom_histogram() +
  geom_vline(xintercept = -1.5 * .6 + 1.5 * .4, lty = 2, color = 'red') +
  geom_vline(xintercept = mean(muestras.normal$estimate), lty = 2, color = 'steelblue') +
  xlim(-1, 1) +
  ggtitle("Normal(0, 2)")

g0 + g1 + g2
