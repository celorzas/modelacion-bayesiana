data {
  int<lower=0> N;
  int y[N];
}

parameters {
  real mu1;
  real mu2;
  real<lower=0, upper=1> omega;
}

model {
  target += log_mix(omega, poisson_log_lpmf(y | mu1), poisson_log_lpmf(y | mu2));
  target += normal_lpdf(mu1 | 3, 1);
  target += normal_lpdf(mu2 | 3, 1);
}
