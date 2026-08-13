%% Moving network simulation
% This script generates a traveling network that moves through space through growing,
% branching, and retracting. 
%
% Editors: Nate Cira, Arnold Chen, Shenghao Tan, Yash Mundewadi

%% PART 0: Initialize, close, clear 
% close all;
% clear all;
% clc
% clear
seed_num = 1; %input('Please enter the seed number: '); %if you want to reproduce same results set a seed
rng(seed_num);
save_wanted = 0 ; %input('Do you want to save? (yes = 1, no = 0): ');
run_num = 1; %input('Enter which simulation number for the same parameters is being run (useful for not accidentally overlapping previously runs): '); %mostly for purposes of saving the output, it will save with this id number
rt = 615; %615 %input('Enter the runtime desired: ');
tic;

%% PART 1: Establish parameters 

%The unit length of the organism, this will be equal to a length of one in
%the simulation (this number is determined by the length that the "tail" of
%the Physarum retracts by, see paper for details)
unit_length = 22.8;

%branching angle (input in degrees, converted to radians)
theta=deg2rad(52.86);

%equilibrium size (the average size of the Physarum in pixels, 
% then divided by the unit length)
eqS = 1146.9/unit_length;

%growth rate (normalized by retraction time scale)
kG= 0.613;

%branching rate (normalized by retraction time scale)
kB= 0.092;

%retraction rate (normalized to 1)
kR=1;

%switching rate (normalized by retraction time scale, and equal to kB for steady state)
kS=kB;

%hill coefficient
n=10;

%minimum number of free leaves
fleafmin=2;

% discretization  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%distance step of branching, growth, retraction
dd=1;

% #time steps per retraction time (higher value indicates more time steps per retraction time scale)
%below sets an optimal dt
dt=max(3*kB+kG,1);

%total time
runtime=rt;

%probabilities
PB = kB/dt;
PG = kG/dt;
PS = kS/dt;
PR = kR/dt;

% Display related %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Display the simulation? if no, 0, if yes, 1, if every x frames, >1
display=1;

%Move display frame with the network? if no, 0, if yes, 1
moveframe=1;

%display size
xdisp = 4000/unit_length;
ydisp = 4000/unit_length;

%write to video
% Create video object
vid = VideoWriter('highquality_model_simulation_maxwin.mp4', 'MPEG-4');
vid.FrameRate = 10;
vid.Quality = 100;
open(vid);


%% PART 2: Set up initial network  %%%%%%
%Note: two vertices are created as the initial state
%Sets up variables vertices, etc. Note the Size_array and Time_array are
%set up inside the for loop.

%initialize two vertices
% vertices each occupy a row in the variable "vertices"
% their data structure is identity, partner1, partner2, partner3, xcoord,
% ycoord, retraction state
vertices=[1 2 0 0 0 0+dd/2 0; 2 1 0 0 0 -dd/2 0];

%initiate storage vertices for plotting color history
cumul_alternative_vertices = [];

% namecounter keeps track of which vertex identities have been used
namecounter=3;

%Other variables (added by Shenghao)
Center = NaN(length(1:ceil(runtime*dt)),2);

%current network size
S=dd;

%AC: for calculating effective kB and effective kG
num_dice_roll = 0;
kB_count = 0;
kG_count = 0;

%AC: for keeping track of network state through time
avg_len_through_time_sum = 0;
avg_num_leaves_through_time_sum = 0;
avg_s_through_time_sum = 0;

%% PART 3: Run the simulation
for t=1:ceil(runtime*dt)
    if mod(t, 10) == 1
        disp(t); %fprintf('t = %d\n', t);
    end
    elims=[];
    newret=0;
    
    %find the leaves
    leaves=find((vertices(:,3)==0 & vertices(:,4)==0) | (vertices(:,2)==0 & vertices(:,3)==0) | (vertices(:,2)==0 & vertices(:,4)==0));
    
    %count how many retracting leaves
    retleaves=find(vertices(:,7)==1);
    numret=length(retleaves);
    
    %manipulate each leaf
    for x=1:length(leaves)
        
        %find vertices which are not retracting
        if vertices(leaves(x),7)==0
            
            %modify the switching probability by size
            mPS=2*PS*1/(1+(eqS/(S))^n);
            
            %roll dice
            dice=rand;
            
            %tracks number of times it checks a leaf (for the purpose of
            %calculating effective branch rate and effective growth rate)
            num_dice_roll = num_dice_roll + 1;
            
            %% Branching %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if dice<PB
                
                kB_count = kB_count + 1;
               
                %find the coordinates of the partner to establish an angle
                %binary search code 
                left=1;
                right=size(vertices,1);
                num = vertices(leaves(x),2);
                
                while left <= right
                    mid = ceil((left + right) / 2);
                    if vertices(mid,1) == num
                        index = mid;
                        %flag = 1;
                        break;
                    else
                        if vertices(mid,1) > num
                            right = mid - 1;
                        else
                            left = mid + 1;
                        end
                    end
                end
                coords = vertices(mid,5:6);
                
                %calculate an angle between the two points
                angle = atan((vertices(leaves(x),6)-coords(2))/(vertices(leaves(x),5)-coords(1)));
                
                if (vertices(leaves(x),6)-coords(2)>=0 && vertices(leaves(x),5)-coords(1)<0) ||(vertices(leaves(x),6)-coords(2)<0 && vertices(leaves(x),5)-coords(1)<0)
                    angle=angle+pi;
                end
                
                %calculate the new vertices' positions
                v1c = [dd*cos(theta/2)*cos(angle)-dd*sin(theta/2)*sin(angle) dd*cos(theta/2)*sin(angle)+dd*sin(theta/2)*cos(angle)]+vertices(leaves(x),5:6);
                v2c = [dd*cos(theta/2)*cos(angle)+dd*sin(theta/2)*sin(angle) dd*cos(theta/2)*sin(angle)-dd*sin(theta/2)*cos(angle)]+vertices(leaves(x),5:6);
                
                %establish the new vertices
                vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v1c(1),v1c(2),0;namecounter+1, vertices(leaves(x),1),0,0,v2c(1),v2c(2),0];
                
                %establish partners in the branching vertex
                vertices(leaves(x),3:4)=[namecounter,namecounter+1];
                
                namecounter=namecounter+2;
                S=S+2*dd;
               

                %% Growth %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif dice<PB+PG
                
                kG_count = kG_count + 1;
                
                %find the coordinates of the partner to establish an angle
                %binary search code
                left=1;
                right=size(vertices,1);
                num = vertices(leaves(x),2);
                
                while left <= right
                    mid = ceil((left + right) / 2);
                    if vertices(mid,1) == num
                        index = mid;
                        %flag = 1;
                        break;
                    else
                        if vertices(mid,1) > num
                            right = mid - 1;
                        else
                            left = mid + 1;
                        end
                    end
                end
                coords = vertices(mid,5:6);
                
                %calculate an angle between the two points
                angle = atan((vertices(leaves(x),6)-coords(2))/(vertices(leaves(x),5)-coords(1)));
                
                if (vertices(leaves(x),6)-coords(2)>=0 && vertices(leaves(x),5)-coords(1)<0) ||(vertices(leaves(x),6)-coords(2)<0 && vertices(leaves(x),5)-coords(1)<0)
                    angle=angle+pi;
                end
                
                %Move the vertex
                vertices(leaves(x),5:6)=[dd*cos(angle) dd*sin(angle)]+vertices(leaves(x),5:6);
                S=S+dd;
               
                %% Switch %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            elseif dice<PB+PG+mPS && length(leaves)-numret-newret>fleafmin
                
                newret=newret+1; % do not allow switching if it would result in less than the minimum number of free leaves
                vertices(leaves(x),7)=1;
                
                %Also store the verticies
                StoreVert;
                
                %% Do nothing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            elseif dice<PB+PG+mPS && length(leaves)-numret-newret<=fleafmin
            else
            end
            
            %% retract if already retracting %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        else
            dice=rand;
            if dice<PR
            %find the coordinates of the partner to establish an angle
            partner = max(vertices(leaves(x),2:4));
            
            left=1;
            right=size(vertices,1);
            num = partner;
            while left <= right
                mid = ceil((left + right) / 2);
                if vertices(mid,1) == num
                    index = mid;
                    %flag = 1;
                    break;
                else if vertices(mid,1) > num
                        right = mid - 1;
                else
                    left = mid + 1;
                end
                end
            end
            %partnerid=find(vertices(:,1) == partner);
            partnerid = mid;
            coords = vertices(partnerid,5:6);
            
            %calculate an angle between the two points
            angle = atan((vertices(leaves(x),6)-coords(2))/(vertices(leaves(x),5)-coords(1)));
            
            if (vertices(leaves(x),6)-coords(2)>=0 && vertices(leaves(x),5)-coords(1)<0) ||(vertices(leaves(x),6)-coords(2)<0 && vertices(leaves(x),5)-coords(1)<0)
                angle=angle+pi;
            end
            %Move the vertex
            vertices(leaves(x),5:6)=[-dd*cos(angle) -dd*sin(angle)]+vertices(leaves(x),5:6);
            S=S-dd;
            
            %remove the vertex and switch the retraction counter (if a new leaf is created) once fully retracted
            if round(5*(coords(1)-vertices(leaves(x),5)))==0 && round(5*(coords(2)-vertices(leaves(x),6)))==0
                elims = [elims; leaves(x)];
                
                for p=2:4
                    if vertices(partnerid,p)==vertices(leaves(x),1)
                        vertices(partnerid,p)=0;
                    end
                end
                
                if sum(vertices(partnerid,2:4)==0)==2
                    vertices(partnerid,7)=1; %the partner node now becomes retracting
                    StoreVertRet; %when the retraction reaches the end, another becomes retracting, the switching along will not account for this
                else
                end
            end
        end
        end
        
    end
    
    % eliminate the removed vertices
    for e=1:length(elims)
        vertices(elims(e),:)=[];
        elims=elims-1;
    end
    %fprintf('Network size: %d\n', S);
    
    % Calculate center of mass
    avgx=mean(vertices(:,5));
    avgy=mean(vertices(:,6));
    
    % Keep track of through time measures 
    avg_len_through_time_sum = avg_len_through_time_sum + S/size(vertices, 1);
    avg_num_leaves_through_time_sum = avg_num_leaves_through_time_sum + length(leaves);
    avg_s_through_time_sum = avg_s_through_time_sum + S;
    
    %% display network
    if rem(t-1,display)==0
        %    render image
        clf
        findfigs
        hold on
        for v=1:size(vertices,1)
            for p=2:4
                if vertices(v,p)~=0
                    for v2=1:size(vertices,1)
                        if vertices(v2,1)==vertices(v,p)
                            plot ([vertices(v,5) vertices(v2,5)], [vertices(v,6) vertices(v2,6)],'k');
                        end
                    end
                end
            end
        end
        
        set(gcf,'WindowState','maximized');  
        
        if moveframe==1
            %calculate centers
            avgx=mean(vertices(:,5));
            avgy=mean(vertices(:,6));
            axis([avgx-xdisp/2 avgx+xdisp/2 avgy-ydisp/2 avgy+ydisp/2])
            axis square
        else
            axis([-xdisp/2 xdisp/2 -ydisp/2 ydisp/2])
            axis square
        end
        hold off
        pause(.02)
        

        frame = getframe(gcf);
        writeVideo(vid, frame);
        
    end
    Center(t,1)=avgx;
    Center(t,2)=avgy;
end

close(vid);

%Store the final state of the
%network
storeFinalNetworkState;


%Calculate average edge length of the final network
avg_len = S/size(vertices, 1);
eff_kG = kG_count / num_dice_roll;
eff_kB = kB_count / num_dice_roll;

%Create figure titles if the network is displayed. Otherwise, don't.
if display ~= 0
    title_str = strcat("Runtime of ", num2str(runtime));
    title_str2 = strcat("Equilibrium Size: ", num2str(eqS), " Final Network Size: ", num2str(S)); 
    title_str3 = strcat("kG: ", num2str(kG), " kB: ", num2str(kB), " kR: ", num2str(kR), " kS: ", num2str(kS));
    title({title_str, title_str2, title_str3});
end

%% PART 4: Save centroid locations into .mat file
%Save the centroid locations to a .mat file with a custom name
avg_len = S/size(vertices, 1);
toc;

Param = [eqS;runtime;kG;kB;kR;kS; seed_num];
Param_strings = ["eqS"; "runtime"; "kG"; "kB"; "kR"; "kS"; "avg_len"; "toc"; "seed_num"];
Track = [avg_len; avg_len_through_time_sum/runtime; avg_num_leaves_through_time_sum/runtime; avg_s_through_time_sum/runtime; toc];
Track_strings = ["avg_len"; "avg_len_through_time"; "avg_num_leaves_through_time"; "avg_s_through_time"; "toc"];
Effec = [num_dice_roll; kG_count; kB_count; eff_kG; eff_kB];
Effec_strings = ["num_dice_roll"; "kG_count"; "kB_count"; "eff_kG"; "eff_kB"];

CT={Center, Param, Param_strings, Track, Track_strings, Effec, Effec_strings, vertices};
mat_name = strcat("Size", num2str(eqS), "_Time", num2str(runtime), "_kG", num2str(kG), "_kB", num2str(kB), "_runnum_", num2str(run_num), "_date_", date, ".mat");
if save_wanted 
    save(mat_name, 'CT'); %Saves variable CT to mat_name. This also means when loaded, it will be variable CT.
end

if display
    regular_name = strcat("Size", num2str(eqS), "_Time", num2str(runtime), "_kG", num2str(kG), "_kB", num2str(kB), "_runnum_", num2str(run_num));
    saveas(gcf, strcat(regular_name, '.fig'), 'fig');
    saveas(gcf, strcat(regular_name, '.jpg'), 'jpeg');
end