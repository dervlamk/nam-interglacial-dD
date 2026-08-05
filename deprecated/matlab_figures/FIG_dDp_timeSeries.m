close all; clear all; clc;
% FIG: Leaf Wax dD time-series
%
%       Dervla Meegan Kumar
%       April, 2022
%

% Set Figure defaults
set(0,'DefaultAxesFontWeight','bold',...
      'DefaultAxesFontSize',12);
set(0,'DefaultTextFontWeight','bold',...
      'DefaultTextFontSize',12);
set(groot, 'DefaultAxesLineWidth',.5,...
           'DefaultAxesXColor', [0,0,0],...
           'DefaultAxesYColor', [0,0,0],...
           'DefaultAxesZColor', [0,0,0]);
       
%% Load Data

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/NH22P/data'
load nh22p_FAMEs_constant_drift_07-Jun-2024.mat

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/DSDP-480-479/data'
load Guaymas_d480_d479_FAMEs_14-Apr-2025.mat

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/global_paleo_data'
load('lr04.mat','delob')

%% Make Fig - LR04 as own axis
f1 = figure(1); clf; hold on;

iters = 1000;
% 95% two-tailed
iupperupper = round(iters * 0.025);
ilowerlower = round(iters * 0.975);

% 90% two-tailed
iupper = round(iters * 0.05);
ilower = round(iters * 0.95);

% 68% two-tailed
iouter = round(iters * 0.16);
iinner = round(iters * 0.84);

% Set time boundaries for cold MIS intervals (2, 3b, 4, 5b, 5d, 6a)
mis_boundaries = [14 38 57 84 105 135;...
                  29 45 71 95 114 141;...
                  29 45 71 95 114 141;...
                  14 38 57 84 105 135];              
% make labels for MIS stages:
str = {'2','3b','4','5b','5d','6a'};
% set x position of MIS labels
text_x = [mean(mis_boundaries(1:2,1))...
          mean(mis_boundaries(1:2,2))...
          mean(mis_boundaries(1:2,3))...
          mean(mis_boundaries(1:2,4))...
          mean(mis_boundaries(1:2,5))...
          mean(mis_boundaries(1:2,6))];

      
modern_Mazatlan = (-29.5 + -32.4 + -33.2)/3;
sig1 = [255 196 0]./255;
sig2 = [255 242 156]./255; 
colline = [235 142 5]./255;
mis_col = [.9 .9 .9];         
xmin = 0;
xmax = 150;


% Calculate 5-point moving average 
dDpMovAvgGuay  = nanmedian(smoothdata(Guay.dDp,'g',5),2);
dDpMovAvg22p   = nanmedian(smoothdata(nh22p.dDp,'g',5),2);


% LR04
subplot(3,1,1); hold on;
    ymax = 5.1;
    ymin = 2.8;
    y1 = repmat([ymin; ymin; ymax; ymax],1,6);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
	text(text_x,...
         repmat(ymin+.1,1,6),...
         str,...
         'HorizontalAlignment','center');
    text(2,2.95,'LR04','Fontsize',16);
    plot(delob(:,1),delob(:,2),'-','color',[.5 .5 .5],'linewidth',1.5);
        set(gca,...
            'Ylim',[ymin ymax],...
            'YTick',[3:.5:5],...
            'ydir','reverse',...
            'ycolor','k');  
        ylabel(['\delta^{18}O (',char(8240),')'])


% Guaymas Basin
subplot(3,1,2); hold on;
    ymax = -39;
    ymin = -75;
    y1 = repmat([ymin; ymin; ymax; ymax],1,6);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
    text(115,-41,'DSDP-480/479','Fontsize',16);
    sortedGuay = sort(Guay.dDp,2);
    Hseb = shadedErrorBar3(Guay.age,nanmedian(Guay.dDp,2),...
                           sortedGuay(:,[ilowerlower iupperupper])',...
                           sortedGuay(:,[iinner iouter])','k'); hold on;
                           set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
                           set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
                           set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
    plot(Guay.age,dDpMovAvgGuay,'-','linewidth',1.5,'color','k');
    set(gca,...
        'Ylim',[ymin ymax],...
        'ycolor','k');
    ylabel(['\delta D_{precip} (',char(8240),')'])


% Mexican Margin
subplot(3,1,3); hold on;
    ymax = -38;
    ymin = -70;
    y1 = repmat([ymin; ymin; ymax; ymax],1,6);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
    text(2,-40,'NH22P','Fontsize',16);
    sorted22p = sort(nh22p.dDp,2);
    Hseb = shadedErrorBar3(nh22p.age,nanmedian(nh22p.dDp,2),...
                           sorted22p(:,[ilowerlower iupperupper])',...
                           sorted22p(:,[iinner iouter])','k'); hold on;
                           set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
                           set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
                           set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
    plot(nh22p.age,dDpMovAvg22p,'-','linewidth',1.5,'color','k');
    %scatter(x,modern_Mazatlan,100,'filled');
    set(gca,...
        'Ylim',[ymin ymax],...
        'ycolor','k');  
    ylabel(['\delta D_{precip} (',char(8240),')'])

        
% Insolation
% subplot(4,1,4); hold on;
%     ymax = 550;
%     ymin = 450;
%     y1 = repmat([ymin; ymin; ymax; ymax],1,6);
% 	patch(mis_boundaries,...
%         y1,...
%         mis_col,...
%         'edgecolor','none',...
%         'handlevisibility','off');
%     plot(insol_age,june21_insol,'-','color','r','linewidth',1.5);
%     text(2,-40,'JUNE 21 45°N','Fontsize',16);
%     set(gca,...
%         'Ylim',[ymin ymax],...
%         'YTick',[ymin:20:ymax],...
%         'ycolor','k');  
%     ylabel('W m^{-2}')
    
    
% figure properties
samexaxis(...
    'YAxisLocation','alternate2',...
    'box','off',...
    'XLim',[xmin xmax],...
    'XTick',[xmin:25:xmax],...
    'XTickLabel',[xmin:25:xmax],...
    'xminortick','on',...
    'YLabelDistance',1,'join');
    xlabel('AGE (ka)');

set(f1,'PaperOrientation','portrait');
set(f1, 'Position',  [0, 0, 600, 1000])
%cd '/Users/dervlakumar/Google_Drive/Research/NAM'
%print('-f1','-bestfit','-painters','dDp_time-series','-dpdf')

%% Make Fig - LR04 plotted against each record
f1 = figure(1); clf; hold on;

iters = 1000;
% 95% two-tailed
iupperupper = round(iters * 0.025);
ilowerlower = round(iters * 0.975);

% 90% two-tailed
iupper = round(iters * 0.05);
ilower = round(iters * 0.95);

% 68% two-tailed
iouter = round(iters * 0.16);
iinner = round(iters * 0.84);
% 
% % Set time boundaries for cold MIS intervals (2, 3b, 4, 5b, 5d, 6a)
% mis_boundaries = [14 38 57 84 105 135;...
%                   29 45 71 95 114 141;...
%                   29 45 71 95 114 141;...
%                   14 38 57 84 105 135];              
% % make labels for MIS stages:
% str = {'2','3b','4','5b','5d','6a'};
% % set x position of MIS labels
% text_x = [mean(mis_boundaries(1:2,1))...
%           mean(mis_boundaries(1:2,2))...
%           mean(mis_boundaries(1:2,3))...
%           mean(mis_boundaries(1:2,4))...
%           mean(mis_boundaries(1:2,5))...
%           mean(mis_boundaries(1:2,6))];

% Set time boundaries for warm MIS intervals (1, 5e)
mis_boundaries = [0    117;...
                  11.7 130;...
                  11.7 130;...
                  0    117];              
% make labels for MIS stages:
str = {'HOL','LIG'};
% set x position of MIS labels
text_x = [mean(mis_boundaries(1:2,1))...
          mean(mis_boundaries(1:2,2))];
      
modern_Mazatlan = (-29.5 + -32.4 + -33.2)/3;
sig1 = [255 196 0]./255;
sig2 = [255 242 156]./255; 
colline = [235 142 5]./255;
mis_col = [.9 .9 .9];         
xmin = 0;
xmax = 150;


% Calculate 5-point moving average 
dDpMovAvgGuay  = nanmedian(smoothdata(Guay.dDp,'g',5),2);
dDpMovAvg22p   = nanmedian(smoothdata(nh22p.dDp,'g',5),2);


% Guaymas Basin
subplot(2,1,1); hold on; box on;
set(gca,'XLim',[xmin xmax],...
    'XTick',[xmin:25:xmax],...
    'XTickLabel',[xmin:25:xmax],...
    'xminortick','on');
    xlabel('AGE (ka)');
   

yyaxis left
    ymax = 5.1;
    ymin = 2.8;
    y1 = repmat([ymin; ymin; ymax; ymax],1,2);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
    text(text_x,...
         repmat(ymin-0.075,1,2),...
         str,...
         'HorizontalAlignment','center');
    %text(2,2.95,'LR04','Fontsize',16);
    plot(delob(:,1),delob(:,2),'-','color',[.5 .5 .5],'linewidth',1.5);
        set(gca,...
            'Ylim',[ymin ymax],...
            'YTick',[3:.5:5],...
            'ydir','reverse',...
            'ycolor','k');  
        ylabel(['\delta^{18}O (',char(8240),')'])

yyaxis right
    ymax = -39;
    ymin = -80;
    text(2,-41,'DSDP-480/479','Fontsize',16);
    sortedGuay = sort(Guay.dDp,2);
    Hseb = shadedErrorBar3(Guay.age,nanmedian(Guay.dDp,2),...
                           sortedGuay(:,[ilowerlower iupperupper])',...
                           sortedGuay(:,[iinner iouter])','k'); hold on;
                           set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
                           set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
                           set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
    plot(Guay.age,dDpMovAvgGuay,'-','linewidth',1.5,'color','k');
    set(gca,...
        'Ylim',[ymin ymax],...
        'ycolor','k');
    ylabel(['\delta D_{precip} (',char(8240),')'])
    
alpha(0.65)


% Mexican Margin
subplot(2,1,2); hold on; box on;
set(gca,'XLim',[xmin xmax],...
    'XTick',[xmin:25:xmax],...
    'XTickLabel',[xmin:25:xmax],...
    'xminortick','on');
    xlabel('AGE (ka)');
    
yyaxis left
    ymax = 5.1;
    ymin = 2.8;
    y1 = repmat([ymin; ymin; ymax; ymax],1,2);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
    text(text_x,...
         repmat(ymin-0.075,1,2),...
         str,...
         'HorizontalAlignment','center');
    plot(delob(:,1),delob(:,2),'-','color',[.5 .5 .5],'linewidth',1.5);
        set(gca,...
            'Ylim',[ymin ymax],...
            'YTick',[3:.5:5],...
            'ydir','reverse',...
            'ycolor','k');  
        ylabel(['\delta^{18}O (',char(8240),')'])

yyaxis right
    ymax = -50;
    ymin = -80;
    text(2,-52,'NH22P','Fontsize',16);
    sorted22p = sort(nh22p.dDp,2);
    Hseb = shadedErrorBar3(nh22p.age,nanmedian(nh22p.dDp,2),...
                           sorted22p(:,[ilowerlower iupperupper])',...
                           sorted22p(:,[iinner iouter])','k'); hold on;
                           set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
                           set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
                           set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
    plot(nh22p.age,dDpMovAvg22p,'-','linewidth',1.5,'color','k');
    %scatter(0,modern_Mazatlan,100,'filled'); % not showing because it's
    %>38
    set(gca,...
        'Ylim',[ymin ymax],...
        'ycolor','k');  
    ylabel(['\delta D_{precip} (',char(8240),')'])
alpha(0.65)  


% figure properties
set(f1,'PaperOrientation','landscape');
set(f1, 'Position',  [0, 0, 800, 800])
cd '/Users/dervlamk/OneDrive/research/nam/figs'
%print('-f1','-bestfit','-painters','dDp_time-series_nh22p_constant_drift','-dpdf')
