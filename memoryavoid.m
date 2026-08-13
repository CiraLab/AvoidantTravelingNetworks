%% Moving network simulation
% This script generates a traveling network moving through space through growing,
% branching, and retracting. An additional modification of self avoidance with memory effects
% is added to this particular script. 
%
%
%% PART 0: Initialize, close, clear %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%close all
%clear all
%clc
%clear
%rng(23)
seed_num = input('Please enter the seed number: ');
rng(seed_num);
save_wanted = input('Do you want to save? (yes = 1, no = 0): ');
run_num = input('Enter which simulation number for the same parameters is being run (useful for not accidentally overlapping previously runs): ');
rt = input('Enter the runtime desired (double check number is what we want): ');
tic;
%% PART 1: Establish parameters %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%branching angle (input in degrees, converted to radians)
%theta=deg2rad(30);
theta=deg2rad(60);

%equilibrium size
eqS=100;

%growth rate (normalized by retraction time scale)
kG=.2;

%branching rate (normalized by retraction time scale)
kB=.1;

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
% Imaginary growth
di=dd+0.2;

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
display=0;

%Move display frame with the network? if no, 0, if yes, 1
moveframe=1;

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
old_vertices = [];

% namecounter keeps track of which vertex identities have been used
namecounter=3;

%Other tracking variables (added by Shenghao)
Center = NaN(length(1:ceil(runtime*dt)),2);
decisionsum = zeros(400,3);
intsum = zeros(400,4);
gpsum = zeros(400,2);
freshleafsum = zeros(400,4);
decisioncounter = 0;

%current network size
S=dd;
%Size_array = NaN(1,length(1:ceil(runtime*dt)));
%Time_array = 1:ceil(runtime*dt);

%for keeping track of network state through time
avg_len_through_time_sum = 0;
avg_num_leaves_through_time_sum = 0;
avg_s_through_time_sum = 0;

%For keeping track of events and calculating effective kB and effective kG
num_dice_roll = 0;
consecutive_no_action = 0;
kB_half_count = 0; %if only one branch extends, increment this counter by 1
kB_full_count = 0; %if both branches extend, increment this counter by 1
kG_count = 0;
kB_reject_count = 0;
kG_reject_count = 0;

%For memory component of the code
original_coord_vertices = [];

%for defining how many time steps the network will remember (e.g. if
%time_thres = 10000, network positions from 1000 time ago will be deleted from memory)
time_thres = 100;

%write display into a movie avi file
if display
    if ~isfolder("network_videos")
        mkdir network_videos;
    end
    vid_name = strcat("network_videos/", "Memory_", "Size", num2str(eqS), "_Time", num2str(runtime), "_kG", num2str(kG), "_kB", num2str(kB), "_runnum_", num2str(run_num), ".avi");
    writerObj = VideoWriter(vid_name);
    writerObj.FrameRate = 5;
    open(writerObj);
end



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

    %manipulate each leaf
    for x=1:length(leaves)
        %2/14/2021 convert old_vertex array to use avoid to
        %determine decision, but don't change the original
        %old_vertex array
        converted_old_vertices = old_vertices(:, 1:(end-1)); %last column in old_vertices show the time memory was created
        if ~isempty(old_vertices)
            old_starting_id = old_vertices(1, 1); 
            largest_id = vertices(end, 1);
            counter = largest_id + 1;
            for ii = 1:2:size(old_vertices, 1)
                %find which column position the partner is assigned.
                pos = find(old_vertices(ii, 2:4) == (old_starting_id+ii)) + 1;
                pos2 = find(old_vertices(ii+1, 2:4) == (old_starting_id)) + 1;
                %Assign new ids to the old vertices when combined with the
                %vertices array
                converted_old_vertices(ii, 1) = counter;
                converted_old_vertices(ii+1, 1) = counter+1;
                %Since the ids are changed for the purpose of combining
                %with the vertices array, also make the partner
                %information at the correponding columns change as a
                %result.
                converted_old_vertices(ii, pos) = counter+1;
                converted_old_vertices(ii+1, pos2) = counter;
                %proceed with the next two nodes (aka next line
                %segment)
                counter = counter + 2;
            end
        end
        old_and_new_vertices = [vertices; converted_old_vertices]; %will use this in the case of branching or growing
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
                %fprintf('branching occurs!\n');
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
                
                decision = avoid(old_and_new_vertices, freshleaf,growthpoint);
                if AvoidOverride > 0
                    decision = [1,1];
                end
                
                %For tracking calculating effective rates
                decision_total = sum(decision);
                if decision_total == 2
                    kB_full_count = kB_full_count + 1;
                elseif decision_total == 1
                    kB_half_count = kB_half_count + 1;
                elseif decision_total == 0
                    kB_reject_count = kB_reject_count + 1;
                end
                
                %decisioncounter = decisioncounter+1;
                %                 freshleafsum(decisioncounter,:) = [v1c v2c];
                %                 decisionsum(decisioncounter,1)=decision(1);
                %                 decisionsum(decisioncounter,2)=decision(2);
                %intsum(decisioncounter,:)=intcount;
                %gpsum (decisioncounter,:)=growthpoint;
                % 5 = branch
                %decisionsum(decisioncounter,3)=5;
                %if both new leaves are good
                [r,c] = size(decision);
                if(c==2 && decision(1) ==1 && decision(2) ==1)
                    vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v1c(1),v1c(2),0;namecounter+1, vertices(leaves(x),1),0,0,v2c(1),v2c(2),0];
                    vertices(leaves(x),3:4)=[namecounter,namecounter+1];
                    namecounter=namecounter+2;
                    S=S+2*dd;
                    %if leaf 2 collides with existing network
                elseif (c==2 && decision(1) ==1 && decision(2) ==0)
                    vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v1c(1),v1c(2),0];
                    vertices(leaves(x),3)=namecounter;
                    namecounter=namecounter+1;
                    S=S+dd;
                    %if leaf 1 collidges with existing network
                elseif (c==2 && decision(1) ==0 && decision(2) ==1)
                    vertices=[vertices; namecounter, vertices(leaves(x),1),0,0,v2c(1),v2c(2),0];
                    vertices(leaves(x),3)=namecounter;
                    namecounter=namecounter+1;
                    S=S+dd;
                end
                
                %% Growth %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif dice<PB+PG
                %fprintf('growth occurs!\n');
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
                [decision out] = avoid(old_and_new_vertices, freshleaf, growthpoint);
                              
                if AvoidOverride > 0
                    decision = 1;
                end
                
                if decision == 1
                    vertices(leaves(x),5:6)=[dd*cos(angle) dd*sin(angle)]+vertices(leaves(x),5:6);
                    S=S+dd;
                end
                
                
                %Code for tracking and calculating effective rates
                kG_count = kG_count + decision;
                kG_reject_count = kG_reject_count - (decision-1);
                %% Switch %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
            elseif dice<PB+PG+mPS && length(leaves)-numret-newret>fleafmin
                
                newret=newret+1; % do not allow switching if it would result in less than the minimum number of free leaves
                vertices(leaves(x),7)=1;
                %mini-step 1: find partners to establish into memory
                partner = max(vertices(leaves(x),2:4)); %This is id information
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
                partnerid = mid; %partnerid=find(vertices(:,1) == partner);
                coords = vertices(partnerid,5:6);
                
                %%mini step 2: Convert into an appropriate format to be
                %%ready to store into old_vertices
                if isempty(old_vertices)
                    begin_ID = 1;
                else
                    begin_ID = old_vertices(end, 1) + 1;
                end
                temp_line = [vertices(leaves(x), :); vertices(partnerid, :)];
                temp_line(1:2, 1) = [begin_ID; begin_ID + 1]; %Assign vertices ID
                nonzero_loc2 = 3; %find(vertices(partnerid, 2:4) == vertices(leaves(x), 1)) + 1; %Finds which of the columns 2-4 contain partner info for the partner node %remember partnerid is the row where it occurs
                nonzero_loc = 2; %find(vertices(leaves(x),2:4)~=0) + 1; %Finds which of the columns 2-4 contain partner info for the original leaf
                temp_line(1, nonzero_loc) = begin_ID + 1; %Assign new vertex ID to that column for original leaf
                temp_line(2, nonzero_loc2) = begin_ID; %Assign new vertex ID to that column for the partner
                possible = 2:4;
                other_loc = ~(2:4 == nonzero_loc);
                other_loc2 = ~(2:4 == nonzero_loc2);
                temp_line(1, possible(other_loc)) = 0;
                temp_line(2, possible(other_loc2)) = 0; %Set partner info for other columns to be zero for the partner (will already be zero for the leaf)
                temp_line(1:2, end+1) = t; 
                
                %mini step 3: actually store into old_vertices
                old_vertices = [old_vertices; temp_line];
                
                %% Do nothing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %original_coord_vertices = [original_coord_vertices; vertices(leaves(x), :)];
                
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
                    %elmination steps
                    elims = [elims; leaves(x)];
                    
                    for p=2:4
                        if vertices(partnerid,p)==vertices(leaves(x),1)
                            vertices(partnerid,p)=0;
                        end
                    end
                    
                    if sum(vertices(partnerid,2:4)==0)==2
                        vertices(partnerid,7)=1;
                        store_into_memory_time210818;
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
    
    % Keep track of through time measures 
    avg_len_through_time_sum = avg_len_through_time_sum + S/size(vertices, 1);
    avg_num_leaves_through_time_sum = avg_num_leaves_through_time_sum + length(leaves);
    avg_s_through_time_sum = avg_s_through_time_sum + S;
    
    %mini step 4: If time step is greater than the threshold, filter old_vertices for entries that are "older" and will be
    %deleted from memory
    if ~isempty(old_vertices)
        if t > time_thres
            remembered_times = old_vertices(:, end);
            logic_retain_memory = remembered_times > (t - time_thres);
            old_vertices = old_vertices(logic_retain_memory, :);
        end
    end
    
    %% display network
    if rem(t-1,display)==0
        %    render image
        clf
        hold on
        %Plots the network using regular vertices. Traced in black.
        %vertices_track keeps track of what vertices have been plotted.
        vertices_track = [];
        for v=1:size(vertices,1)
            for p=2:4
                if vertices(v,p)~=0
                    for v2=1:size(vertices,1)
                        if vertices(v2,1)==vertices(v,p)
                            plot ([vertices(v,5) vertices(v2,5)], [vertices(v,6) vertices(v2,6)],'k.-', 'LineWidth', 2, 'MarkerSize', 8);
                            curr_line = [vertices(v,5) vertices(v2,5) vertices(v,6) vertices(v2,6)];
                            vertices_track = [vertices_track; curr_line];
                        end
                    end
                end
            end
        end
        
        %Plots the network using old vertices with old
        %line segments. Traced in red. Idea is if the line segments does
        %not exist in vertices_track, then plot it here in red.
        for v=1:size(old_vertices,1)
            for p=2:4
                if old_vertices(v,p)~= 0
                    for v2=1:size(old_vertices,1)
                        if old_vertices(v2,1) == old_vertices(v,p)
                            curr_line = [old_vertices(v,5) old_vertices(v2,5) old_vertices(v,6) old_vertices(v2,6)];
                            check_match = (curr_line == vertices_track);
                            if max(sum(check_match, 2)) ~= size(curr_line, 2) %the line segment does not already exist in the curent statem of the network, plot line in red that was in the network previously but no longer exists.
                                plot ([old_vertices(v,5) old_vertices(v2,5)], [old_vertices(v,6) old_vertices(v2,6)],'r.-', 'LineWidth', 1, 'MarkerSize', 8);
                            end
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
        frame = getframe(gcf);
        writeVideo(writerObj, frame);
        hold off
        pause(0.05)
    end
    
    %Size_array(t)=S;
    Center(t,1)=avgx;
    Center(t,2)=avgy;
    if AvoidOverride > 0
        AvoidOverride = AvoidOverride - 1;
    end

%     Two methods, essentially equivalent below for determining if system is "stuck"
    % Check the last 50 centroids, consider a dead end if all are the same (network "stuck")
    buffer = 10;
    if t> (50 + buffer)
        CompX = Center(t-50:t,1);
        CompY = Center(t-50:t,2);
        if range(CompX)==0 && range(CompY)==0 && AvoidOverride ==0
            % If the network reaches a dead end, in the next n timesteps self avoiding
            % decisions will be overridden, guaranteeing growth / branching if chosen
            AvoidOverride = 5;
            trapped = trapped + 1;
        end
    end
%     if action_taken
%         consecutive_no_action = 0;
%     elseif action_taken == false
%         consecutive_no_action = consecutive_no_action + 1;
%         if consecutive_no_action == 50
%             AvoidOverride = 5;
%             trapped = trapped + 1;
%             consecutive_no_action = 0;
%         end
%     end
end

%%
%Create figure titles if the network is displayed. Otherwise, don't.
if display ~= 0
    title_str0 = "Self Avoidance with Memory (black = current; red = memory)";
    title_str = strcat("Runtime of ", num2str(runtime));
    title_str2 = strcat("Equilibrium Size: ", num2str(eqS), " Final Network Size: ", num2str(S));
    title_str3 = strcat("kG: ", num2str(kG), " kB: ", num2str(kB), " kR: ", num2str(kR), " kS: ", num2str(kS));
    title({title_str0, title_str, title_str2, title_str3});
end

if display
    %close video file
    close(writerObj);
end

toc;
%% PART 4: Save centroid locations into .mat file
%Save the centroid locations to a .mat file with a custom name
if save_wanted
    avg_len = S/size(vertices, 1);
    
    eff_kG = kG_count / num_dice_roll;
    eff_kB = (kB_half_count*0.5 + kB_full_count*1) / num_dice_roll;
    
    Param = [eqS;runtime;kG;kB;kR;kS; seed_num; time_thres];
    Track = [avg_len; avg_len_through_time_sum/runtime; avg_num_leaves_through_time_sum/runtime; avg_s_through_time_sum/runtime; toc];
    Effec = [num_dice_roll; kG_count; kB_half_count; kB_full_count; kG_reject_count; kB_reject_count; eff_kG; eff_kB; trapped];
    Param_strings = ["eqS"; "runtime"; "kG"; "kB"; "kR"; "kS"; "seed_num"; "time_thres"];
    Track_strings = ["avg_len"; "avg_len_through_time"; "avg_num_leaves_through_time"; "avg_s_through_time"; "toc"];
    Effec_strings = ["num_dice_roll"; "kG_count"; "kB_half_count"; "kB_full_count"; "kG_reject_count"; "kB_reject_count"; "eff_kG"; "eff_kB"; "trapped"];
    
    CT={Center, Param, Param_strings, Track, Track_strings, Effec, Effec_strings, vertices, old_vertices};
    mat_name = strcat("Memory_Centroid_TimeDecay", num2str(time_thres), "_Size", num2str(eqS), "_Time", num2str(runtime), "_kG", num2str(kG), "_kB", num2str(kB), "_runnum_", num2str(run_num), "_date_", date, ".mat");
    save(mat_name, 'CT'); %Saves variable CT to mat_name. This also means when loaded, it will be variable CT.
    
    if display
        memory_name = strcat("Memory_Centroid_TimeDecay", num2str(time_thres), "_Size", num2str(eqS), "_Time", num2str(runtime), "_kG", num2str(kG), "_kB", num2str(kB), "_runnum_", num2str(run_num));
        saveas(gcf, strcat(memory_name, '.fig'), 'fig');
        saveas(gcf, strcat(memory_name, '.jpg'), 'jpeg');
    end   
end