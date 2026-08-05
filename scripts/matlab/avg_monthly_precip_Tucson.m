f1 = figure(1); clf;

%make column vector of avg monthly precip for Tucson, AZ from US Climate Data
T_precip = [1.02 1.02 0.94 0.87 0.31 0.2 0.28 1.93 2.24 1.22 1.22 0.67]';

%set labels for x-axis
months = {'D'; 'J'; 'F'; 'M'; 'A'; 'M'; 'J'; 'J'; 'A'; 'S'; 'O'; 'N'};

bar(TUS_precip);
        set(gca,'XLim',[0 13],'XTick',[1:1:12],'XTickLabel',months,'XColor','k');
        ytickformat('%.1f')
        set(gca,'YLim',[0 2.5],'YTick',[0:.5:2.5],'YMinorTick','on','fontsize',24,'YColor','k');
        
        ylabel('Avg. Monthly Rainfall (inches)');
        xlabel('Month');