// Based on https://github.com/anastasiachtz/COMMAND_stan/blob/master/SingleStrainStan.Rmd
// documented in https://arxiv.org/pdf/1903.00423.pdf

functions {
  
  // Deterministic ODE of the SIR model. Function signature matches rk45 solver's expectation.
  real[] SIR(
    real t,       // Time period; unused.
    real[] y,     // System state {susceptible,infected,recovered}.
    real[] theta, // Parameters.
    real[] x_r,   // Continuous-valued data; unused.
    int[] x_i     // Integer-valued data; unused.
  ) {
    real dy_dt[3];
    
    dy_dt[1] = -theta[1] * y[1] * y[2];
    dy_dt[2] = theta[1] * y[1] * y[2] - theta[2] * y[2];
    dy_dt[3] = theta[2] * y[2];
    
    return dy_dt;
  }
  
}

data {
  int<lower = 1> n_obs;       // Number of days observed.
  int<lower = 1> n_theta;     // Number of model parameters.
  int<lower = 1> n_difeq;     // Number of differential equations.
  int<lower = 1> n_pop;       // Population.
  int y[n_obs];           // Data: total number of infected individuals each day
  real t0;      // Initial time tick for the ODE solver. Must be provided in the data block.
  real ts[n_obs];  // Time ticks for the ODE solver. Must be provided in the data block.
}
  
transformed data {
  // Covariates for the ODE solver. Not used here, but must be provided.
  real x_r[0];
  // Integer covariates for the ODE solver. Not used here, but must be provided.
  int x_i[0];
}
  
parameters {
  real<lower=0> theta[n_theta];   // ODE model parameters {beta,gamma}
  real<lower=0, upper=1> S0;      // initial fraction of susceptible individuals
}
  
transformed parameters{
  real y_hat[n_obs, n_difeq]; // solution from the ODE solver
  real y_init[n_difeq];       // initial conditions for both fractions of S and I
  
  y_init[1] = S0;
  y_init[2] = 1 - S0;
  y_init[3] = 0;
  y_hat = integrate_ode_rk45(SIR, y_init, t0, ts, theta, x_r, x_i);
}
  
model {
  real lambda[n_obs];              // Poisson rate parameter at each time point.
  
  // Priors.
  theta[1] ~ lognormal(0,1);
  theta[2] ~ gamma(0.004,0.02);  // Assume mean infectious period = 5 days 
  S0 ~ beta(0.5, 0.5);
  
  // Likelihood
  for (i in 1:n_obs){
    // Public datasets report cumulative confirmed cases, which is I+R in this model.
    lambda[i] = (y_hat[i,2] + y_hat[i,3]) * n_pop;
  }
  y ~ poisson(lambda);
}
  
generated quantities {
  real R_0;      // Basic reproduction number
  R_0 = theta[1]/theta[2];
  
  
}
