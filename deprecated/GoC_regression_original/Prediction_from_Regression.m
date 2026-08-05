%Prediction from Regression script
%PREDICTING VALUES OF X FROM VALUES OF Y
%you have a time series of dD measurements from a sediment
%core, and you want to predict rainfall from them...in other words you are doing
%what a typical paleoclimatologist does - inferring a climate variable from
%a proxy. 
%P(rainfall|dD)~P(dD|rainfall)*P(rainfall).

%P(dD|rainfall) = the distributions and results from your regression (load
%the workspace)

%P(rainfall) = a prior distribution you specify; 

timeseries = dD_data; %input the correct sites' data here, should dDp estimate;

N_Ts=length(timeseries);
%assign prior mean, standard deviation, will depend on the variable you're
%predicting - choose the mean and variance based on modern data
prior_mean=76; 
prior_std = 12;
%calculate inverse variance b/c will need it below...
prior_inv_var = prior_std^(-2);


%Now do the prediction
results=NaN(N_Ts,length(tau2_draws_final));

for i=1:length(tau2_draws_final)
    beta_now=b_draws_final(i,1);
    alpha_now=b_draws_final(i,2);
    tau_now=tau2_draws_final(i);
    %calculate the posterior covariance based on iterative formula:
    post_cov=1/(prior_inv_var + beta_now^2/tau_now);
    %now calculate the first factor of the posterior mean, vectorize as you
    %do it:
    mean_first=prior_inv_var*eye(N_Ts) * prior_mean*ones(N_Ts,1) + (1/tau_now) * beta_now * (timeseries - alpha_now);
    
    %then calculate the full mean of the posterior.
    Mean_full=post_cov*eye(N_Ts)*mean_first;
    
    %make a draw from the distribution 
    results(:,i) = normrnd(Mean_full,sqrt(post_cov));

end
clearvars beta_now alpha_now post_cov prior_inv_var tau_now mean_first N_Ts Mean_full timeseries;