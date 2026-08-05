%CODE TO CORRECT FOR d13C (C3/C4) contribution and estimate dD of
%precip (from Tripti Bhattacharya, 2022)

%set d13C endmembers
c4end =-24.2;%C4 mean -22;
c4std=3.2;%C4 standard error, adjusted 9/17/2021 for Desert Museum Samples
% 
c3end=-32.7; %C3 mean -34
c3std=4;%C3 stdev/sqrt number of samples

%set dD epilson endmembers
c4dd = -107.8; %Desert Museum Compilation, only includes 3 taxa, but in ballpark of western US measurements of Sachse
c4dd_s = 3.7; %stdev/n-1
c3dd = -82; %C3 dicots, Sachse et al. 2012 -113
c3dd_s = 1; %stdev/n-1

%set number of iterations
iters = 2500;

%uniform assumption:
m = 0.5;
n = 2;

age = ones(length(dD(:,1)));
%d13c = Coretop_d13C;
c30_iv = IVcorr;
%d13c = -34.*ones(length(IVcorr),1)+2.*randn(length(IVcorr),1);
%d13c = interp1(d13C_raw(:,1),d13C_raw(:,2),dD(:,1),'previous','extrap');
std_d = ones(length(dD(:,2)),1)*2;%ones(length(c30_iv))*2;

%calc estimated fraction C4:
f4=NaN(length(age),iters);
dd_est=NaN(length(age),iters);

for i=1:iters
 %likelihood of C4 plant:
c4 = normrnd(c4end,c4std);
c3 = normrnd(c3end,c3std);
N = 5000;
%enter d13c data here
Y = ((d13c(:,1)+normrnd(0,0.2))-c3)./(c4-c3)*N;

%Bayesian posterior
a = Y + (n*m)-1;
b = N-Y + (n*(1-m)) - 1;

f4(:,i) = betarnd(a,b);
%calculate an epsilon, this is just Monte Carlo
    c4d = normrnd(c4dd,c4dd_s);
    c3d = normrnd(c3dd,c3dd_s);
    ep=(f4(:,i).*c4d)+((1-f4(:,i)).*c3d);
    %sample a dd series
    %std_d=2; %this is analytical stdev
    %enter dd timeseries here, ice-volume correct first (c30_iv in this example)
    fame_s=c30_iv + 2*randn(length(c30_iv),1); %instead of random errors, add in analytical stddev here. 
    %apply epsilon to dd
    dd_est(:,i)=(1000+fame_s)./(ep/1000+1)-1000;
end
clearvars a age b c3 c30_iv c3d c3dd c3dd_s c3end c3std c4 c4d c4dd c4dd_s c4end c4std d13c ep fame_s iters i m n N std_d Y
%
%save('dD.mat','dd_est','f4','-append');

