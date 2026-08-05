close all; clear all; clc;
% FIG: %JAS time-series
%
%       Dervla Meegan Kumar
%       May, 2022
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
load nh22p_FAMEs_06-May-2024.mat

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/eastern_pacific_cores/DSDP-480-479/data'
load Guaymas_d480_d479_FAMEs_06-May-2024.mat

cd '/Users/dervlamk/Library/CloudStorage/OneDrive-UCIrvine/research/global_paleo_data'
load('lr04.mat','delob')

%% Make Fig
f1 = figure(1); clf; hold on;

iters = 4000;
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
jasMovAvgGuay  = nanmedian(smoothdata(Guay.jas,'g',5),2);
jasMovAvg22p   = nanmedian(smoothdata(nh22p.jas,'g',5),2);


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
    ymax = 60;
    ymin = -20;
    y1 = repmat([ymin; ymin; ymax; ymax],1,6);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
    text(105,60,'DSDP-480/479','Fontsize',16);
    sortedGuay = sort(Guay.jas,2);
    Hseb = shadedErrorBar3(Guay.age,nanmedian(Guay.jas,2),...
                           sortedGuay(:,[ilowerlower iupperupper])',...
                           sortedGuay(:,[iinner iouter])','k'); hold on;
                           set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
                           set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
                           set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
    plot(Guay.age,jasMovAvgGuay,'-','linewidth',1.5,'color','k');
    set(gca,...
        'Ylim',[ymin ymax],...
        'ycolor','k');
    ylabel('%JAS')


% Mexican Margin
subplot(3,1,3); hold on;
    ymax = 65;
    ymin = -10;
    y1 = repmat([ymin; ymin; ymax; ymax],1,6);
	patch(mis_boundaries,...
        y1,...
        mis_col,...
        'edgecolor','none',...
        'handlevisibility','off');
    text(2,60,'NH22P','Fontsize',16);
    sorted22p = sort(nh22p.jas,2);
    Hseb = shadedErrorBar3(nh22p.age,nanmedian(nh22p.jas,2),...
                           sorted22p(:,[ilowerlower iupperupper])',...
                           sorted22p(:,[iinner iouter])','k'); hold on;
                           set(Hseb.mainLine,'Color',colline,'linewidth',1.2);
                           set(Hseb.patch1,'facecolor',sig2,'edgecolor','none');
                           set(Hseb.patch2,'facecolor',sig1,'edgecolor','none');
    plot(nh22p.age,jasMovAvg22p,'-','linewidth',1.5,'color','k');
    %scatter(x,modern_Mazatlan,100,'filled');
    set(gca,...
        'Ylim',[ymin ymax],...
        'ycolor','k');  
    ylabel('%JAS')

        
        
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
set(f1, 'Position',  [0, 0, 500, 900])
%cd '/Users/dervlakumar/Google_Drive/Research/NAM'
print('-f1','-bestfit','-painters','pJAS_time-series','-dpdf')
