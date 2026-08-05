%Prior and posteriors for the top samples as validation of your ability to
%invert and predict from your regression


xt2 =[20:0.001:105];
set(gcf,'pos',[100 500 900 230]);
figure(6);
subplot(1,2,1)
xt=xt2;
data=reshape(Regresults_2517-2,4000*32,1);
post=ksdensity(data,xt,'Support','positive'); hold on;
prior=normpdf(xt,70,15);
p1=plot(xt,prior*10,'k','linewidth',1.5); hold on;
p2=plot(xt,post*10,'r','linewidth',1.5);
set(gca,'box','on','linewidth',.75);
legend([p1 p2],'Prior','Posterior');
legend('boxoff');
title('Guaymas basin');
ylabel('Prob. density');

subplot(1,2,2)
xt2 = [20:0.001:105];
data=Regresults_8P(2,:)-2;
post=ksdensity(data,xt2); hold on;
posttest = ksdensity(data,xt2,'Function','cdf');
prior=normpdf(xt2,74,15);
p1=plot(xt2,prior*10,'k','linewidth',1.5); hold on;
p2=plot(xt2,post*10,'r','linewidth',1.5); 
set(gca,'box','on','linewidth',.75);
legend([p1 p2],'Prior','Posterior');
legend('boxoff');
title('Mazatlan');