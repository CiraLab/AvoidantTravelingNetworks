%This script stores cumulative vertices info
%Used in conjunction with base model

%Do retraction until it hits its partner

dummy_vertices = vertices;

%Find the partner node
partner = max(dummy_vertices(leaves(x),2:4)); %should only have one nonzero, hence using max
left=1;
right=size(dummy_vertices,1);
num = partner;
while left <= right
    mid = ceil((left + right) / 2);
    if dummy_vertices(mid,1) == num
        index = mid;
        %flag = 1;
        break;
    else if dummy_vertices(mid,1) > num
            right = mid - 1;
    else
        left = mid + 1;
    end
    end
end
%partnerid=find(dummy_vertices(:,1) == partner);
partnerid = mid;
coords = dummy_vertices(partnerid,5:6);


%Construct the cumulative vertices array

cumul_alternative_vertices = [cumul_alternative_vertices; dummy_vertices(leaves(x), :); dummy_vertices(partnerid, :)];







