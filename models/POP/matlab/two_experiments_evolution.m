function two_experiments_evolution(files, titles, varnames, qtty, prpo, levelind)
%%
% Each variable gets its own figure.
% Each region gets its own axis.
%
% I'm having some problems preserving the ticks on the left,
% so I used a transparent object. Because of THAT - OpenGL is the
% default rendered, which is normally a pretty low resolution.
% For good reproducibility, manually specify the 'painters' option when
% printing.
% 
% files = {'/fs/image/home/thoar/DART/models/POP/work/dart.005/obs_diag_output.nc', ...
%          '/fs/image/home/thoar/DART/models/POP/work/c.cam23.2/obs_diag_output.nc', ...
%          '/fs/image/home/thoar/DART/models/POP/work/c.cam48v3.serr.c020/obs_diag_output.nc'};
% titles   = {'23 POP 1 DATM', '23 POP 23 CAM', '48 POP 48 CAM'};
% varnames = {'XBT_TEMPERATURE', 'CTD_SALINITY'};
% qtty     = 'spread';     % rmse, spread, totalspread, bias, etc.
% prpo     = 'analysis'; % [analy, analysis, posterior ] == posterior
% prpo     = 'both'; % prior & posterior
% prpo     = 'forecast'; % [guess, forecast, prior     ] == prior
% levelind = 1;
%
% two_experiments_evolution(files, titles, varnames, qtty, prpo, levelind)
% print -dpsc -painters myplot.ps
%
% <next few lines under version control, do not edit>
% $URL$
% $Id$
% $Revision$
% $Date$

%%--------------------------------------------------------------------
% Decode,Parse,Check the input
%---------------------------------------------------------------------

if (length(files) ~= length(titles))
   error('each file must have a title')
end

NumExp = length(files);

for i = 1:NumExp
   if (exist(files{i},'file') ~= 2)
      error('File %s does not exist',files{i})
   end
end

%% set up all the stuff that is common. 

commondata = check_compatibility(files, varnames, qtty);
figuredata = setfigure(commondata);

%%--------------------------------------------------------------------
% Set some static data
%---------------------------------------------------------------------

nvars = length(varnames);

for ivar = 1:nvars
   fprintf('Working on %s ...\n',varnames{ivar})

   for ireg = 1:commondata.nregions

      figure(ireg);
      clf;

      %---------------------------------------------------------------------
      % Getting the data for each experiment
      %---------------------------------------------------------------------

      Nlimits = zeros(NumExp,2);  % range of observation count - min, then max
      Dlimits = zeros(NumExp,2);  % range of the data
      Ylimits = zeros(NumExp,2);  % range of the vertical coords
      plotobj = cell(1,NumExp);

      for iexp = 1:NumExp

         plotobj{iexp} = getvals(files{iexp}, varnames{ivar}, qtty, prpo, ireg, levelind);
         plotobj{iexp}.title        = titles{iexp};
         plotobj{iexp}.nregions     = commondata.nregions;
         plotobj{iexp}.region_names = commondata.region_names;

         Nlimits(iexp,:) = plotobj{iexp}.Nrange;
         Dlimits(iexp,:) = plotobj{iexp}.Drange;
         Ylimits(iexp,:) = plotobj{iexp}.Drange;

      end

      %---------------------------------------------------------------------
      % Find nice limits that encompass all experiments
      %---------------------------------------------------------------------

      Nrange = [min(Nlimits(:,1)) max(Nlimits(:,2))];
      Drange = [min(Dlimits(:,1)) max(Dlimits(:,2))];
      Yrange = [min(Ylimits(:,1)) max(Ylimits(:,2))];

      %---------------------------------------------------------------------
      % Plot all regions - one month to a page
      %---------------------------------------------------------------------

      myplot( plotobj, Nrange, Drange, Yrange, figuredata);

   end % of loop around regions

   BottomAnnotation(files)
   
   if ( ivar ~= nvars )
      disp('Pausing, hit any key to continue ...')
      pause
   end

end  % of loop around variable

%=====================================================================
% End of main function body. Helper functions below.
%=====================================================================



function common = check_compatibility(filenames, varnames, copystring)
%----------------------------------------------------------------------
% Trying to prevent the comparison of apples and oranges.
% make sure the diagnostics were generated the same way.

% need to check that the timeframe is the same for all files

% need to check that the region definitions are the same for all files 

mystat     = 0;
nexp       = length(filenames);
commondata = cell(1,nexp);
priornames = struct([]);
postenames = struct([]);

for i = 1:length(varnames)
    priornames{i} = sprintf('%s_guess',varnames{i});
    postenames{i} = sprintf('%s_analy',varnames{i});
end

for i = 1:nexp

   varexist(filenames{i}, {priornames{:}, postenames{:}, 'time', 'time_bounds'})

   diminfo = nc_getdiminfo(filenames{i},    'copy'); ncopies   = diminfo.Length;  
   diminfo = nc_getdiminfo(filenames{i},'obstypes'); nobstypes = diminfo.Length;  
   diminfo = nc_getdiminfo(filenames{i},  'region'); nregions  = diminfo.Length;  

   commondata{i}.ncopies   = ncopies;
   commondata{i}.nobstypes = nobstypes;
   commondata{i}.nregions  = nregions;
   commondata{i}.times     = nc_varget(filenames{i},'time');
   commondata{i}.time_bnds = nc_varget(filenames{i},'time_bounds');
   commondata{i}.copyindex = get_copy_index(filenames{i},copystring);
   commondata{i}.lonlim1   = nc_attget(filenames{i},nc_global,'lonlim1');
   commondata{i}.lonlim2   = nc_attget(filenames{i},nc_global,'lonlim2');
   commondata{i}.latlim1   = nc_attget(filenames{i},nc_global,'latlim1');
   commondata{i}.latlim2   = nc_attget(filenames{i},nc_global,'latlim2');

   commondata{i}.region_names = nc_varget(filenames{i},'region_names');

   if (commondata{i}.nregions == 1 && (size(commondata{i}.region_names,2) == 1) )
       commondata{i}.region_names = deblank(commondata{i}.region_names');
   end

end

% error checking - compare everything to the first experiment
for i = 2:nexp

   if (any(commondata{i}.lonlim1 ~= commondata{1}.lonlim1))
      fprintf('The left longitudes of the regions (i.e. lonlim1) are not compatible.\n')
      mystat = 1;
   end

   if (any(commondata{i}.lonlim2 ~= commondata{1}.lonlim2))
      fprintf('The right longitudes of the regions (i.e. lonlim2) are not compatible.\n')
      mystat = 1;
   end

   if (any(commondata{i}.latlim1 ~= commondata{1}.latlim1))
      fprintf('The bottom latitudes of the regions (i.e. latlim1) are not compatible.\n')
      mystat = 1;
   end

   if (any(commondata{i}.latlim2 ~= commondata{1}.latlim2))
      fprintf('The top latitudes of the regions (i.e. latlim2) are not compatible.\n')
      mystat = 1;
   end

   if (any(commondata{i}.time_bnds ~= commondata{1}.time_bnds))
      fprintf('The time boundaries of the experiments (i.e. time_bnds) are not compatible.\n')
      mystat = 1;
   end

end

if mystat > 0
   error('The experiments are not compatible ... stopping.')
end

common = commondata{1};



function plotdat = getvals(fname, varname, copystring, prpo, regionindex, levelindex )
%----------------------------------------------------------------------
if (exist(fname,'file') ~= 2)
   error('%s does not exist',fname)
end

plotdat.fname         = fname;
plotdat.varname       = varname;  
plotdat.copystring    = copystring;
plotdat.region        = regionindex;
plotdat.levelindex    = levelindex;
plotdat.bincenters    = nc_varget(fname,'time');
plotdat.binedges      = nc_varget(fname,'time_bounds');
plotdat.mlevel        = nc_varget(fname,'mlevel');
plotdat.plevel        = nc_varget(fname,'plevel');
plotdat.plevel_edges  = nc_varget(fname,'plevel_edges');
plotdat.hlevel        = nc_varget(fname,'hlevel');
plotdat.hlevel_edges  = nc_varget(fname,'hlevel_edges');
plotdat.ncopies       = length(nc_varget(fname,'copy'));

plotdat.binseparation      = nc_attget(fname, nc_global, 'bin_separation');
plotdat.binwidth           = nc_attget(fname, nc_global, 'bin_width');
plotdat.rat_cri            = nc_attget(fname, nc_global, 'rat_cri');
plotdat.input_qc_threshold = nc_attget(fname, nc_global, 'input_qc_threshold');
plotdat.lonlim1            = nc_attget(fname, nc_global, 'lonlim1');
plotdat.lonlim2            = nc_attget(fname, nc_global, 'lonlim2');
plotdat.latlim1            = nc_attget(fname, nc_global, 'latlim1');
plotdat.latlim2            = nc_attget(fname, nc_global, 'latlim2');
plotdat.biasconv           = nc_attget(fname, nc_global, 'bias_convention');

% Coordinate between time types and dates

timeunits             = nc_attget(fname,'time','units');
calendar              = nc_attget(fname,'time','calendar');
timebase              = sscanf(timeunits,'%*s%*s%d%*c%d%*c%d'); % YYYY MM DD
timeorigin            = datenum(timebase(1),timebase(2),timebase(3));

plotdat.bincenters    = plotdat.bincenters + timeorigin;
plotdat.binedges      = plotdat.binedges   + timeorigin;
plotdat.Nbins         = length(plotdat.bincenters);

plotdat.timespan      = sprintf('%s through %s', ...
                        datestr(min(plotdat.binedges(:))), ...
                        datestr(max(plotdat.binedges(:))));

% Get the right indices for the intended variable, regardless of the storage order
% as well as some indices of other quantities of interest for future use.

plotdat.copyindex     = get_copy_index(fname, copystring);
plotdat.Npossindex    = get_copy_index(fname, 'Nposs');
plotdat.Nusedindex    = get_copy_index(fname, 'Nused');
plotdat.NQC4index     = get_copy_index(fname, 'N_DARTqc_4');
plotdat.NQC5index     = get_copy_index(fname, 'N_DARTqc_5');
plotdat.NQC6index     = get_copy_index(fname, 'N_DARTqc_6');
plotdat.NQC7index     = get_copy_index(fname, 'N_DARTqc_7');

plotdat.priorvar      = sprintf('%s_guess',plotdat.varname);
plotdat.postevar      = sprintf('%s_analy',plotdat.varname);

myinfo.diagn_file     = fname;
myinfo.copyindex      = plotdat.copyindex;
myinfo.regionindex    = plotdat.region;
myinfo.levelindex     = plotdat.levelindex;

% get appropriate vertical coordinate variable

guessdims = nc_var_dims(fname, plotdat.priorvar);
analydims = nc_var_dims(fname, plotdat.postevar);

if ( findstr('surface',guessdims{3}) > 0 )
   plotdat.level       = 1;
   plotdat.level_units = 'surface';
   plotdat.level_edges = [];
elseif ( findstr('undef',guessdims{3}) > 0 )
   plotdat.level       = 1;
   plotdat.level_units = 'undefined';
   plotdat.level_edges = [];
else
   plotdat.level       = nc_varget(fname, guessdims{3});
   plotdat.level_units = nc_attget(fname, guessdims{3}, 'units');
   plotdat.level_edges = nc_varget(fname,sprintf('%s_edges',guessdims{3}));
end

[start, count]        = GetNCindices(myinfo,'diagn',plotdat.priorvar);
plotdat.prior         = nc_varget(fname, plotdat.priorvar, start, count);

[start, count]        = GetNCindices(myinfo,'diagn',plotdat.postevar);
plotdat.poste         = nc_varget(fname, plotdat.postevar, start, count);

%% Determine data limits - Do we use prior and/or posterior
%  always make sure we have a zero bias line ...

plotdat.useposterior = 0;
plotdat.useprior     = 0;
switch lower(prpo)
   case {'analy','analysis','posterior'}
      plotdat.useposterior = 1;
      bob = plotdat.poste(:);
   case {'guess','forecast','prior'}
      plotdat.useprior = 1;
      bob = plotdat.prior(:);
   otherwise
      plotdat.useposterior = 1;
      plotdat.useprior = 1;
      bob = [plotdat.prior(:) ; plotdat.poste(:)];   % one long array
end

switch copystring
case {'bias'}
   dmin = min( [ min(bob) 0.0 ] );
   dmax = max( [ max(bob) 0.0 ] );
   plotdat.Drange = [ dmin dmax ];
   plotdat.ylabel = sprintf('%s %s',copystring, plotdat.biasconv);
otherwise
   plotdat.Drange = [min(bob) max(bob)];
   plotdat.ylabel = copystring;
end

%% Get the number of observations possible and the number used.
%  N_DARTqc_6 is the number ignored because of incoming QC values.
%  It doesn't matter which prior/poste variable you get this information
%  from - they are both the same.
%
%  For POP - N_DARTqc_4 is the number rejected because of land/ocean
%  interpolation issues.

myinfo.diagn_file = fname;
myinfo.copyindex  = plotdat.Npossindex;
myinfo.levelindex = plotdat.levelindex;

[start, count]    = GetNCindices(myinfo,'diagn',plotdat.priorvar);
plotdat.nposs     = nc_varget(fname, plotdat.priorvar, start, count);

myinfo.copyindex  = plotdat.NQC4index;
[start, count]    = GetNCindices(myinfo,'diagn',plotdat.priorvar);
plotdat.Nqc4      = nc_varget(fname, plotdat.priorvar, start, count);

myinfo.copyindex  = plotdat.NQC6index;
[start, count]    = GetNCindices(myinfo,'diagn',plotdat.priorvar);
plotdat.Nqc6      = nc_varget(fname, plotdat.priorvar, start, count);

if ( plotdat.useprior )
   myinfo.copyindex = plotdat.Nusedindex;
   [start, count]   = GetNCindices(myinfo,'diagn',plotdat.priorvar);
   plotdat.nused    = nc_varget(fname, plotdat.priorvar, start, count); 
else
   myinfo.copyindex = plotdat.Nusedindex;
   [start, count]   = GetNCindices(myinfo,'diagn',plotdat.postevar);
   plotdat.nused    = nc_varget(fname, plotdat.postevar, start, count);   
end

% The POP model ... Nqc4 are land/water interpolation issues.
% Nqc6 is disregarded because of incoming qc.

plotdat.nposs = plotdat.nposs - plotdat.Nqc4 - plotdat.Nqc6;

%% Set the last of the ranges

plotdat.Nrange = [min(plotdat.nused(:))    max(plotdat.nposs(:))];


function myplot( plotobj, Nrange, Drange, Yrange, figdata)
%% myplot Creates a graphic for one region

Nexp    = size(plotobj,2);
iregion = plotobj{1}.region;
    
%% Create the background

ax1   = subplot('position',figdata.plotlims(iregion,:));
set(ax1,'YAxisLocation','left','FontSize',figdata.fontsize)
hold on
     
%% draw the results of the experiments, priors and posteriors
%  each with their own line type.
iexp   = 0;
hd     = [];   % handle to an unknown number of data lines
legstr = {[]}; % strings for the legend

for i = 1:Nexp

   if ( plotobj{i}.useprior )
      iexp         = iexp + 1;
      lty          = sprintf('%s%s%s',figdata.expcolors{i},figdata.prpolines{1}, ...
                                      figdata.expsymbols{i});
      hd(iexp)     = plot(plotobj{i}.bincenters, plotobj{i}.prior, lty,'LineWidth', 2.0);
      legstr{iexp} = plotobj{i}.title;
   end
  
   if ( plotobj{i}.useposterior ) 
      iexp         = iexp + 1;
      lty          = sprintf('%s%s%s',figdata.expcolors{i},figdata.prpolines{2}, ...
                                      figdata.expsymbols{i});
      hd(iexp)     = plot(plotobj{i}.bincenters, plotobj{i}.poste, lty,'LineWidth', 2.0);
      legstr{iexp} = plotobj{i}.title;
   end
end

%% hokey effort to decide to plot months/days vs. daynum vs.
ttot = plotobj{1}.bincenters(plotobj{1}.Nbins) - plotobj{1}.bincenters(1) + 1;

if ((plotobj{1}.bincenters(1) > 1000) && (ttot > 5))
      datetick('x',6,'keeplimits','keepticks');
      monstr = datestr(plotobj{1}.bincenters(1),21);
      xlabelstring = sprintf('month/day - %s start',monstr);
elseif (plotobj{1}.bincenters(1) > 1000)
      datetick('x',15,'keeplimits','keepticks')
      monstr = datestr(plotobj{1}.bincenters(1),21);
      xlabelstring = sprintf('%s start',monstr);
else
      xlabelstring = 'days';
end

% FIXME - this cant work
switch plotobj{1}.copystring
case {'bias'}
      biasline = line([0 0],Yrange,'Color','k','Parent',ax1);
      set(biasline,'LineWidth',2.0,'LineStyle','-.')
otherwise
end

grid(ax1,'on')
hold off;

%% Create another axes to use for plotting the observation counts

ax2 = axes('position',get(ax1,'Position'), ...
        'XAxisLocation','top', ...
        'YAxisLocation','right',...
        'Color','none',...
        'XColor','b','YColor','b',...
        'XLim',get(ax1,'XLim'), ...
        'YDir',get(ax1,'YDir'));

% Plot the data, which sets the range of the axis
for i = 1:Nexp
   h2 = line(plotobj{i}.bincenters, plotobj{i}.nposs,'Color',figdata.expcolors{i},'Parent',ax2);
   h3 = line(plotobj{i}.bincenters, plotobj{i}.nused,'Color',figdata.expcolors{i},'Parent',ax2);
   set(h2,'LineStyle','none','Marker',figdata.expsymbols{i});
   set(h3,'LineStyle','none','Marker','+');
end

% use same X ticks
set(ax2,'XTick',     get(ax1,'XTick'), ...
        'XTicklabel',get(ax1,'XTicklabel'));

% use the same Y ticks, but find the right label values
[yticks, newticklabels] = matchingYticks(ax1,ax2);
set(ax2,'YTick', yticks, 'YTicklabel', newticklabels)

% Annotate the whole thing - gets pretty complicated for multiple
% regions on one page. Trying to maximize content, minimize clutter.


annotate( ax1, ax2, plotobj{i}, figdata)

lh = legend(hd,legstr);
legend(lh,'boxoff');

set(lh,'FontSize',figdata.fontsize);
kids = get(lh,'Children');
%if (length(kids) < 8)
%   set(kids([2 5]),'LineWidth',2.0);
%else
%   set(kids([2 5 8 11]),'LineWidth',2.0);
%end


function annotate(ax1, ax2, plotobj, figdata)

%% One figure ... everything gets annotated.

set(get(ax1,'Xlabel'),'String',plotobj.timespan,'Interpreter','none','FontSize',figdata.fontsize)
set(get(ax2,'Ylabel'),'String','# of obs (o=poss, +=used)')

if ( plotobj.useprior )
   ylabel = sprintf('forecast %s',plotobj.ylabel);
else
   ylabel = sprintf('analysis %s',plotobj.ylabel);
end

set(get(ax1,'Ylabel'),'String',ylabel,'Interpreter','none','FontSize',figdata.fontsize)

th = title({deblank(plotobj.region_names(plotobj.region,:)), ...
       sprintf('%s @ %d %s', plotobj.varname, ...
                             plotobj.level(plotobj.levelindex), ...
                             plotobj.level_units)});
set(th,'Interpreter','none','FontSize',figdata.fontsize);


function BottomAnnotation(filenames)
% annotates the filename containing the data being plotted
nfiles = length(filenames);
dy     = 1.0/(nfiles+1);   % vertical spacing for text

subplot('position',[0.10 0.01 0.8 0.05])
axis off

for ifile = 1:nfiles
   main = filenames{ifile};

   fullname = which(main);   % Could be in MatlabPath
   if( isempty(fullname) )
      if ( main(1) == '/' )  % must be a absolute pathname
         string1 = sprintf('data file: %s',main);
      else                   % must be a relative pathname
         mydir = pwd;
         string1 = sprintf('data file: %s/%s',mydir,main);
      end
   else
      string1 = sprintf('data file: %s',fullname);
   end

   ty = 1.0 - (ifile-1)*dy;
   h = text(0.5, ty, string1);
   set(h, 'Interpreter', 'none', 'FontSize', 8);
   set(h, 'HorizontalAlignment','center');
end



function [yticks newticklabels] = matchingYticks(ax1, ax2)
%% This takes the existing Y ticks from ax1 (presumed nice)
% and determines the matching labels for ax2 so we can keep
% at least one of the axes looking nice.

ylimits = get(ax2,'YLim');
Dlimits = get(ax1,'YLim');
DYticks = get(ax1,'YTick');
nYticks = length(DYticks);

slope   = (ylimits(2) - ylimits(1))/(Dlimits(2) - Dlimits(1));
xtrcpt  = ylimits(2) -slope*Dlimits(2);

yticks        = slope*DYticks + xtrcpt;
newticklabels = num2str(round(10*yticks')/10);



function varexist(filename, varnames)
%% We already know the file exists by this point.
% Lets check to make sure that file contains all needed variables.

nvars  = length(varnames);
gotone = ones(1,nvars);

for i = 1:nvars
   gotone(i) = nc_isvar(filename,varnames{i});
   if ( ~ gotone(i) )
      fprintf('\n%s is not a variable in %s\n',varnames{i},filename)
   end
end

if ~ all(gotone)
   error('missing required variable ... exiting')
end


function figdata = setfigure(commondata)
%%
%  the hardest part is figuring out the gaps, etc.
%  gapwidth = (1 - (nregions*axiswidth + 0.14))/(nregions - 1)
%  0.14 is actually left margin + right margin ... 0.07 + 0.07 

plotlims = zeros(commondata.nregions,4);

if (commondata.nregions > 4) 
   error('Cannot handle %d regions - 4 is the max.',commondata.nregions)

elseif (commondata.nregions == 999) 
   orientation   = 'tall';
   fontsize      = 10;
   plotlims(1,:) = [0.100 0.560 0.375 0.355];
   plotlims(2,:) = [0.525 0.560 0.375 0.355];
   plotlims(3,:) = [0.100 0.125 0.375 0.355];
   plotlims(4,:) = [0.525 0.125 0.375 0.355];

elseif (commondata.nregions == 998) 
   orientation   = 'landscape';
   fontsize      = 12;
   plotlims(1,:) = [0.0700 0.14 0.265 0.725];
   plotlims(2,:) = [0.3675 0.14 0.265 0.725];
   plotlims(3,:) = [0.6650 0.14 0.265 0.725];

elseif (commondata.nregions == 997) 
   orientation   = 'landscape';
   fontsize      = 12;
   plotlims(1,:) = [0.10 0.62 0.725 0.375];
   plotlims(2,:) = [0.10 0.14 0.725 0.375];

else
   orientation   = 'landscape';
   fontsize      = 16;
   plotlims(1,:) = [0.10 0.12 0.8 0.75];
   plotlims(2,:) = [0.10 0.12 0.8 0.75];
   plotlims(3,:) = [0.10 0.12 0.8 0.75];
   plotlims(4,:) = [0.10 0.12 0.8 0.75];
end

figdata = struct('expcolors',  {{'k','r','b','g','m','c','y'}}, ...
                 'expsymbols', {{'o','s','d','p','h','s','*'}}, ...
                 'prpolines',  {{'-',':'}}, 'plotlims', plotlims, ...
                 'fontsize',fontsize, 'orientation',orientation);

clf; orient(gcf, orientation)
