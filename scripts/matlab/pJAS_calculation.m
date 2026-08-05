%%  CODE TO CORRECT CALCULATE %JAS RAINFALL FROM dD_precip
%   (modified code originally written by Tripti Bhattacharya)
%
%
%   Dervla Meegan Kumar
%   April 2022
%

%%

%Univariate (only estimated one slope) Bayesian regression for dD data and
%environmental data
X = X(:,1);%percent_JAS;
Y = Y(:,1);%dD;
%scatter(X,Y); %if you're curious

%Least squares estimate of the parameters
test     = length(X);
X        = [X ones(test,1)];
Bhat     = inv((X'*X))*(X'*Y);
iObs     = size(X,1);
iR       = size(X,2);
m_p      = Bhat;
numparam = size(X,2);
tau2hat  = 1/(iObs-numparam)*(Y-X*Bhat)'*(Y-X*Bhat);

%Covariance matrix
cov_p       = 5*eye(length(Bhat)); %choose a big number here - big is relative to data
cov_p(1,1)  = 0.15;
cov_p(2,2)  = 100;

%Calculate the prior distribution for P(bhat,tau2hat|data);
%Specify parameters for the inverse gamma distribution. 

%Higher values make the parameters more peaked. Remember that the first 
%moment of a gamma is a/b and inverse gamma is b/(a-1) - can help determine right ballpark of estimates.

a = 1; b = 15;

x3 = [0:.01:20];
y1 = b^a/gamma(a)*x3.^(-a-1).*exp(-b./x3);

figure(3); clf;
plot(x3,y1,'color','k');
hold on;
s1=plot(tau2hat,max(y1),'ro');
title('Inverse Gamma Prior on Variance');
%Shows your initial 'confidence' in your estimate of variance;

Nc=10; %number of chains
Nd=1000; %number of draws
b_draws=NaN(Nc,Nd,iR);
tau2_draws=NaN(Nc,Nd,1);
N=length(X);

for i=1:Nc
tau2_val = 5*rand(1,1); 

for kk =1:Nd
    %Conditional posterior distribution of parameters
    b_covar=(((X'*X)/tau2_val + inv(cov_p)))^(-1); %estimate of covariance
    b_mn=(cov_p\m_p+X'*Y/tau2_val)'*b_covar; %reg parameters, estimate depends on previous estimate of covariance
    b_val=mvnrnd(b_mn,b_covar)'; % Full distribution of the parameters
    %marginal posterior distribution of tau^2:
    p_a = a+N/2; %shape parameter
    p_b=b+(1/2)*(Y-X*b_val)'*(Y-X*b_val); %scale parameter
    
    tau2_val= 1/gamrnd(p_a,1/p_b);
    tau2_val= min(100,tau2_val);    %Choose a large number that is unrealistically large for threshold, as the point of this
                                    %is to reduce weed out large
                                    %error estimates
    
    b_draws(i,kk,:)=b_val;
    tau2_draws(i,kk)=tau2_val;
end
end

mean(mean(b_draws(:,:,1)));
mean(mean(b_draws(:,:,2)));
mean(tau2_draws(:));

figure(4); clf;
subplot(3,1,1)
plot(1:size(b_draws,2), b_draws(:,:,1))
set(gca,'xlim',[0 200]);
title('Slope');
subplot(3,1,2)
plot(1:size(b_draws,2), b_draws(:,:,2))
set(gca,'xlim',[0 200]);
title('Intercept');
subplot(3,1,3)
plot(1:size(b_draws,2),tau2_draws)
set(gca,'xlim',[0 200]);
title('Error variance');

%Weed out initial estimates - should NOT really matter for data that is IID
%and Gaussian, but can matter in some cases - to test plot both ranges of
%distribution
b_draws=b_draws(:,201:end,:);
tau2_draws=tau2_draws(:,201:end);

%Here, we look at how different or similar the chains are - depends on the
%number of draws in each. This is assessed using Rhat statistic
m=size(b_draws,1);
n=size(b_draws,2);
Bs_var=n/(m-1)*sum((mean(b_draws(:,:,1),2)-mean(mean(b_draws(:,:,1),2))).^2); %Essentially comparing variance within a chain vs. 
Ws_var=mean(var(b_draws(:,:,1),0,2));                                         %pooled estimates across all chains - should be 
Rhat=sqrt(((n-1)/n*Ws_var+1/n*Bs_var)/Ws_var);                                %close to 1          

b_draws_r=reshape(b_draws,size(b_draws,1)*size(b_draws,2),size(b_draws,3));
tau2_draws_r=reshape(tau2_draws,size(tau2_draws,1)*size(tau2_draws,2),1);
b_draws_final=b_draws_r(1:2:end,:);
tau2_draws_final=tau2_draws_r(1:2:end);


%Plot prior and posterior distributions
%Use the following as a guide for the range of values for your x axes...
xt1int = ((Bhat(1)/100));
xt1lim1 = Bhat(1) - 5;
xt1lim2 = Bhat(1) + 5;

xt2int = ((Bhat(2)/100));
xt2lim1 = Bhat(2) - 20;
xt2lim2 = Bhat(2) + 20;

xt3int = mean(tau2_draws_final,1)/100;
xt3lim1 = min(tau2_draws_final,1) - 5;
xt3lim2 = max(tau2_draws_final,1) + 5;

set(gcf,'pos',[100 500 900 230]);
figure(6);
subplot(1,3,1)
xt=[xt1lim1:xt1int:xt1lim2];
slope=b_draws_final(:,1);
post=ksdensity(slope(:),xt,'Support','positive'); hold on;
prior=normpdf(xt,m_p(1),sqrt(mean(cov_p(1,1))));
p1=plot(xt,prior*0.1,'k','linewidth',1.5); hold on;
p2=plot(xt,post*0.1,'r','linewidth',1.5);
set(gca,'box','on','linewidth',.75);
legend([p1 p2],'Prior','Posterior');
legend('boxoff');
xlim([-1 1.5])
title('Slope \beta');
ylabel('Prob. density');

subplot(1,3,2)
xt=[-110:0.05:-10];
intercept=b_draws_final(:,2);
post=ksdensity(intercept(:),xt); hold on;
prior=normpdf(xt,m_p(2),sqrt(mean(cov_p(2,2))));
p1=plot(xt,prior,'k','linewidth',1.5); hold on;
p2=plot(xt,post,'r','linewidth',1.5); 
set(gca,'box','on','linewidth',.75);
legend([p1 p2],'Prior','Posterior');
legend('boxoff');
xlim([-100 -20])
title('Intercept \alpha');

subplot(1,3,3)
xt=[0:0.01:100];
post=ksdensity(tau2_draws_final(:),xt);
prior = b^a/gamma(a)*xt.^(-a-1).*exp(-b./xt);                   %Remember to use inverse gamma, not gamma
p1=plot(xt,prior,'k','linewidth',1.5); hold on;
p2=plot(xt,post,'r','linewidth',1.5);
set(gca,'box','on','linewidth',.75);
legend([p1 p2],'Prior','Posterior');
legend('boxoff');
title('Error variance (\tau^2)');
