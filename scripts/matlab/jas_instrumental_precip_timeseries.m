%% Set Figure defaults
set(0,'DefaultAxesFontWeight','bold',...
      'DefaultAxesFontSize',12);
set(0,'DefaultTextFontWeight','bold',...
      'DefaultTextFontSize',12);
set(groot, 'DefaultAxesLineWidth',.5,...
           'DefaultAxesXColor', [0,0,0],...
           'DefaultAxesYColor', [0,0,0],...
           'DefaultAxesZColor', [0,0,0]);
       
%% D
f2 = figure(2); clf;

% bar(TUS_JAS(:,1),TUS_JAS(:,2));
%         set(gca,'XLim',[1899.5 2020],'XTick',[1900:10:2020],'XTickLabel',[1900:10:2020],'Xminortick','on','tickdir','out','XColor','k');
%         set(gca,'YLim',[0 15],'YTick',[0:5:15],'YMinorTick','on','fontsize',24,'YColor','k');
%         ylabel('Total Monsoon Rainfall (inches)');
        
        
plot(TUS_JAS(:,1),TUS_JAS(:,2),'-','LineWidth',3,'Color','k');
    set(gca,'XLim',[1899.5 2020],'XTick',[1900:10:2020],'XTickLabel',[1900:10:2020],'Xminortick','on','tickdir','out','XColor','k');
    set(gca,'YLim',[0 15],'YTick',[0:5:15],'YMinorTick','on','fontsize',24,'YColor','k');
    ylabel('Total Monsoon Rainfall (inches)');