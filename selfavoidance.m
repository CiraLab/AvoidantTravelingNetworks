%% Moving network simulation
% This script generates a network diffusing through space through growing,
% branching, and retracting. An additional modification of self avoidance
% is added to this particular script.
%

% Editors: Arnold Chen, Nate Cira, Yash Mundewadi, Shenghao Tan

%% PART 0: Initialize, close, clear %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
close all
clear all
clc
clear
seed_num = input('Please enter the seed number: ');
rng(seed_num);
save_wanted = input('Do you want to save? (yes = 1, no = 0): ');
run_num = input('Enter which simulation number for the same parameters is being run (useful for not accidentally overlapping previously runs): ');
rt = input('Enter the runtime desired (double check number is what we want): ');
tic;
%% PART 1: Establish parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%branching angle (input in degrees, converted to radians)
%theta=deg2rad(30);
theta = deg2rad(60);

%equilibrium size
eqS = 100;

%growth rate (normalized by retraction time scale)
kG = .2;

%branching rate (normalized by retraction time scale)
kB = .1;

%retraction rate (normalized to 1)
kR = 1;

%switching rate (normalized by retraction time scale, and equal to kB for steady state)
kS = kB;
 
%hill coefficient
n = 10;

%minimum number of free leaves
fleafmin = 2;

% discretization  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%distance step of branching, growth, retraction
dd = 1;
% Imaginary growth
di = dd+0.2;

% #time steps per retraction time (higher value indicates more time steps per retraction time scale)
%below sets an optimal dt
dt=max(3*kB+kG,1);

% Override timer
AvoidOverride = 0;

%total time
runtime = rt;

%probabilities
PB = kB/dt;
PG = kG/dt;
PS = kS/dt;
PR = kR/dt;

% Trap counter
trapped = 0;

% Display related %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Display the simulation? if no, 0, if yes, 1, if every x frames, >1
display = 0;

%Move display frame with the network? if no, 0, if yes, 1
moveframe = 1;

%display size
xdisp = 80;
ydisp = 80;


%% PART 2: Set up initial network  %%%%%%
%Note: two vertices are created as the initial state
%Sets up variables vertices, Size_array, Time_array, etc.

%initialize two vertices
% vertices each occupy a row in the variable "vertices"
% their data structure is identity, partner1, partner2, partner3, xcoord,
% ycoord, retraction state
vertices=[1 2 0 0 0 0+dd/2 0; 2 1 0 0 0 -dd/2 0];

%initiate storage vertices for existing network
oldvertices=vertices;

% namecounter keeps track of which vertex identities have been used
namecounter=3;

%Other tracking variables 
Center = NaN(length(1:ceil(runtime*dt)),2);
decisionsum = zeros(400,3);
intsum = zeros(400,4);
gpsum = zeros(400,2);
freshleafsum = zeros(400,4);
decisioncounter = 0;

%current network size
S=dd;
Size_array = NaN(1,length(1:ceil(runtime*dt)));
Time_array = 1:ceil(runtime*dt);

%Tallies for calculating effective kB and effective kG
num_dice_roll = 0;
kB_half_count = 0; %if only one branch extends, increment this counter by 1
kB_full_count = 0; %if both branches extend, increment this counter by 1
kG_count = 0;
kB_reject_count = 0;
kG_reject_count = 0;

%% PART 3: Run the simulation
for t=1:ceil(runtime*dt)
    if mod(t, 10000) == 1
        disp(t);
    end
    elims=[];
    newret=0;
    
    %find the leaves
    leaves=find((vertices(:,3)==0 & vertices(:,4)==0) | (vertices(:,2)==0 & vertices(:,3)==0) | (vertices(:,2)==0 & vertices(:,4)==0));
    
    %count how many retracting leaves
    retleaves=find(vertices(:,7)==1);
    numret=length(retleaves);
    
    %Keeping track of whether any branching or growth occurred during this time step, 
    %then change cosecutive_no_action in the end
    action_taken = false;
    
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
                
                %find the coordinates of the partner to establish an angle
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
                growthpoint = [vertices(leaves(x),5) vertices(leaves(x),6)];
                %calculate an angle between the two points
                angle = atan((vertices(leaves(x),6)-coords(2))/(vertices(leaves(x),5)-coords(1)));
                
                if (vertices(leaves(x),6)-coords(2)>=0 && vertices(leaves(x),5)-coords(1)<0) ||(vertices(leaves(x),6)-coords(2)<0 && vertices(leaves(x),5)-coords(1)<0)
                    angle=angle+pi;
                end
                
                %calculate the new vertices' positions
                v1c = [dd*cos(theta/2)*cos(angle)-dd*sin(theta/2)*sin(angle) dd*cos(theta/2)*sin(angle)+dd*sin(theta/2)*cos(angle)]+vertices(leaves(x),5:6);
                v2c = [dd*cos(theta/2)*cos(angle)+dd*sin(theta/2)*sin(angle) dd*cos(theta/2)*sin(angle)-dd*sin(theta/2)*cos(angle)]+vertices(leaves(x),5:6);
                v1i = [di*cos(theta/2)*cos(angle)-di*sin(theta/2)*sin(angle) di*cos(theta/2)*sin(angle)+di*sin(theta/2)*cos(angle)]+vertices(leaves(x),5:6);
                v2i = [di*cos(theta/2)*cos(angle)+di*sin(theta/2)*sin(angle) di*cos(theta/2)*sin(angle)-di*sin(theta/2)*cos(angle)]+vertices(leaves(x),5:6);
                freshleaf =[v1i;v2i];
                %establish the new vertices
                %Store the old vertice to compare the the new
                %leaf growth, to detect collision
                %newvertices = [namecounter, vertices(leaves(x),1),0,0,v1c(1),v1c(2),0;namecounter+1, vertices(leaves(x),1),0,0,v2c(1),v2c(2),0];
                %
                decision = avoid(vertices, freshleaf,growthpoint);
                if AvoidOverride > 0
                    decision = [1,1];
                end
                
                %For tracking and calculating effective rates
                decision_total = sum(decision);
                if decision_total == 2
                    kB_full_count = kB_full_count + 1;
                elseif decision_total == 1
                    kB_half_count = kB_half_count + 1;
                elseif decision_total == 0
                    kB_reject_count = kB_reject_count + 1;
                end
                
                %                 decisioncounter = decisioncounter+1;
                %                 freshleafsum(decisioncounter,:) = [v1c v2c];
                %                 decisionsum(decisioncounter,1)=decision(1);
                %                 decisionsum(decisioncounter,2)=decision(2);
                %intsum(decisioncounter,:)=intcount;
                %                 gpsum (decisioncounter,:)=growthpoint;
                % 5 = branch
                %                 decisionsum(decisioncounter,3)=5;
                %if both new leaves are good
                [r,c] = size(decision);
                if(c==2 && decision(1) ==1 && decision(2) ==1)
                    vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v1c(1),v1c(2),0;namecounter+1, vertices(leaves(x),1),0,0,v2c(1),v2c(2),0];
                    if sum(vertices(leaves(x), 3:4)) ~= 0
                        error('exit script. Reassigning nonempty locations!');
                    end
                    vertices(leaves(x),3:4)=[namecounter,namecounter+1];
                    namecounter=namecounter+2;
                    S=S+2*dd;
                    %if leaf 2 collides with existing network
                elseif (c==2 && decision(1) ==1 && decision(2) ==0)
                    vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v1c(1),v1c(2),0];
                      if sum(vertices(leaves(x), 3:4)) ~= 0
                        error('exit script. Reassigning nonempty locations!');
                    end
                    vertices(leaves(x),3)=namecounter;
                    namecounter=namecounter+1;
                    S=S+dd;
                    %if leaf 1 collidges with existing network
                elseif (c==2 && decision(1) ==0 && decision(2) ==1)
                    vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v2c(1),v2c(2),0];
                      if sum(vertices(leaves(x), 3:4)) ~= 0
                        error('exit script. Reassigning nonempty locations!');
                    end
                    vertices(leaves(x),3)=namecounter;
                    namecounter=namecounter+1;
                    S=S+dd;
                end
                
                if action_taken == false
                    action_taken = (sum(decision) > 0);
                end
                %establish partners in the branching vertex
                %                 vertices(leaves(x),3:4)=[namecounter,namecounter+1];
                %                 namecounter=namecounter+2;
                %                 S=S+2*dd;
                
                %% Growth %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif dice<PB+PG
                
                %find the coordinates of the partner to establish an angle
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
                growthpoint = [vertices(leaves(x),5) vertices(leaves(x),6)];
                %calculate an angle between the two points
                angle = atan((vertices(leaves(x),6)-coords(2))/(vertices(leaves(x),5)-coords(1)));
                
                if (vertices(leaves(x),6)-coords(2)>=0 && vertices(leaves(x),5)-coords(1)<0) ||(vertices(leaves(x),6)-coords(2)<0 && vertices(leaves(x),5)-coords(1)<0)
                    angle=angle+pi;
                end
                %Move the vertex
                vx = di*cos(angle)+vertices(leaves(x),5);
                vy = di*sin(angle)+vertices(leaves(x),6);
                freshleaf = [vx vy];
                decision = avoid(vertices, freshleaf, growthpoint);
                if AvoidOverride > 0
                    decision = 1;
                end
                
                if action_taken == false
                    action_taken = decision;
                end
                %                 decisioncounter = decisioncounter+1;
                %                 freshleafsum(decisioncounter,1:2)=freshleaf;
                %                 decisionsum(decisioncounter,1)=decision(1);
                %                 decisionsum(decisioncounter,3)=7;
                %                 %intsum(decisioncounter,1)=intcount(1);
                %                 %intsum(decisioncounter,2)=intcount(2);
                %                 gpsum (decisioncounter,:)=growthpoint;
                % 7 = growth;
                %                 [r,c] = size(decision);
                if decision == 1
                    vertices(leaves(x),5:6)=[dd*cos(angle) dd*sin(angle)]+vertices(leaves(x),5:6);
                    S=S+dd;
                end
                
                %For tracking and calculating effective rates
                kG_count = kG_count + decision;
                kG_reject_count = kG_reject_count - (decision-1);
                
                %% Switch %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            elseif dice<PB+PG+mPS && length(leaves)-numret-newret>fleafmin
                
                newret=newret+1; % do not allow switching if it would result in less than the minimum number of free leaves
                vertices(leaves(x),7)=1;
                
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
                    else
                        if vertices(mid,1) > num
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
                %(vertices(leaves(x),6)-coords(2))=0.5 /
                %(vertices(leaves(x),5)-coords(1)) = 0
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
                        vertices(partnerid,7)=1;
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
    
    % Calculate center of mass
    avgx=mean(vertices(:,5));
    avgy=mean(vertices(:,6));
    
    %% display network
    if rem(t-1,display)==0
        %    render image
        clf
        hold on
        for v=1:size(vertices,1)
            for p=2:4
                if vertices(v,p)~=0
                    for v2=1:size(vertices,1)
                        if vertices(v2,1)==vertices(v,p)
                            plot ([vertices(v,5) vertices(v2,5)], [vertices(v,6) vertices(v2,6)],'k.-')
                        end
                    end
                end
            end
        end
        
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
        curr_t = num2str(t);
        new_str = "Current time t: " + curr_t;
        title(new_str);
        hold off
        pause(.05)
    end
    Size_array(t)=S;
    Center(t,1)=avgx;
    Center(t,2)=avgy;
    % Countdown on AvoidOverride
    if AvoidOverride > 0
        AvoidOverride = AvoidOverride - 1;
    end

%     Two methods, essentially equivalent below for determining if system is "stuck"
    % Check the last 50 centroids, consider a dead end if all are the same (alternate method for determining if system is "stuck")
%     if t>60
%         CompX = Center(t-50:t,1);
%         CompY = Center(t-50:t,2);
%         if range(CompX)==0 && range(CompY)==0 && AvoidOverride ==0
%             % If the network reaches a dead end, in the next n timesteps self avoiding
%             % decisions will be overridden, guaranteeing growth / branching if chosen
%             AvoidOverride = 5;
%             trapped = trapped + 1;
%         end
%     end
     if action_taken
        consecutive_no_action = 0;
    elseif action_taken == false
        consecutive_no_action = consecutive_no_action + 1;
        if consecutive_no_action == 50
            AvoidOverride = 5;
            trapped = trapped + 1;
            consecutive_no_action = 0;
        end
    end
end

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
eff_kG = kG_count / num_dice_roll;
eff_kB = (kB_half_count*0.5 + kB_full_count*1) / num_dice_roll;
toc;

Param = [eqS;runtime;kG;kB;kR;kS; seed_num];
Track = [avg_len; toc];
Effec = [num_dice_roll; kG_count; kB_half_count; kB_full_count; kG_reject_count; kB_reject_count; eff_kG; eff_kB; trapped];
Param_strings = ["eqS"; "runtime"; "kG"; "kB"; "kR"; "kS"; "seed_num"];
Track_strings = ["avg_len"; "toc"];
Effec_strings = ["num_dice_roll"; "kG_count"; "kB_half_count"; "kB_full_count"; "kG_reject_count"; "kB_reject_count"; "eff_kG"; "eff_kB"; "trapped"];

CT={Center, Param, Param_strings, Track, Track_strings, Effec, Effec_strings, vertices};
mat_name = strcat("Avoid_", "Size", num2str(eqS), "_Time", num2str(runtime), "_kG", num2str(kG), "_kB", num2str(kB), "_runnum_", num2str(run_num), ".mat");
if save_wanted
    save(mat_name, 'CT'); %Saves variable CT to mat_name. This also means when loaded, it will be variable CT.
end

