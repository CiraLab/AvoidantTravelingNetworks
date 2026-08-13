%This script is a part of the script that given 
%leaves(x), find the partner and store into memory. 

%The memoryavoid script uses this script. 

%Separated from main script to attempt to reduce clutter

%mini-step 1: find partners to establish into memory
new_partner = max(vertices(partnerid,2:4)); %This is id information
left=1;
right=size(vertices,1);
num = new_partner;
while left <= right
    mid = ceil((left + right) / 2);
    if vertices(mid,1) == num
        index = mid;
        break;
    else
        if vertices(mid,1) > num
            right = mid - 1;
        else
            left = mid + 1;
        end
    end
end
new_partnerid = mid; 
coords = vertices(new_partnerid,5:6);

%%mini step 2: Convert into an appropriate format to be
%%ready to store into old_vertices. temp_line has two rows, where each row
%%represents each node of a line segment. 
if isempty(old_vertices)
    begin_ID = 1;
else
    begin_ID = old_vertices(end, 1) + 1;
end
temp_line = [vertices(partnerid, :); vertices(new_partnerid, :)];
temp_line(1:2, 1) = [begin_ID; begin_ID + 1]; %Assign vertices ID
nonzero_loc2 = 3; 
nonzero_loc = 2; 
temp_line(1, nonzero_loc) = begin_ID + 1; %Assign new vertex ID to that column for original leaf
temp_line(2, nonzero_loc2) = begin_ID; %Assign new vertex ID to that column for the partner
possible = 2:4;
other_loc = ~(2:4 == nonzero_loc);
other_loc2 = ~(2:4 == nonzero_loc2);
temp_line(1, possible(other_loc)) = 0;
temp_line(2, possible(other_loc2)) = 0; %Set partner info for other columns to be zero for the partner (will already be zero for the leaf)
temp_line(1:2, end+1) = t; %This represents the time that this node is stored into memory (relevant in the version where memory decays through time)

%mini step 3: actually store into old_vertices
old_vertices = [old_vertices; temp_line];