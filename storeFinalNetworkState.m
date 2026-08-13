%This script stores the final state of the network

vertices;
dummy_vertices = vertices; %to prevent altering the original dummy_vertices array
trying_cumul_alternative = cumul_alternative_vertices;
tracker = 0;

while ~isempty(dummy_vertices)
    tracker = tracker + 1;
    writematrix(dummy_vertices, "dummy_vertices.xlsx", 'Sheet', tracker);
    writematrix(trying_cumul_alternative, 'trying_cumul_alternative.xlsx', 'Sheet', tracker);
    elims = [];

    %find the leaves
    leaves=find((dummy_vertices(:,3)==0 & dummy_vertices(:,4)==0) | (dummy_vertices(:,2)==0 & dummy_vertices(:,3)==0) | (dummy_vertices(:,2)==0 & dummy_vertices(:,4)==0));
    for x = 1:length(leaves)   
        partner = max(dummy_vertices(leaves(x),2:4));
        left=1;
        right=size(dummy_vertices,1);
        num = partner;
        while left <= right
            mid = ceil((left + right) / 2);
            if dummy_vertices(mid,1) == num
                index = mid;
                break;
            else if dummy_vertices(mid,1) > num
                    right = mid - 1;
            else
                left = mid + 1;
            end
            end
        end
        partnerid = mid;
               
        if sum(dummy_vertices(partnerid, 1) == trying_cumul_alternative (:, 1)) >= 1 && sum(dummy_vertices(leaves(x), 1) == trying_cumul_alternative (:, 1)) >= 1
            %     %don't store it as they are part of the same segment and
            %     %already recorded down in cumul_alternative_vertices

        else
            %do store it
            trying_cumul_alternative  = [trying_cumul_alternative; dummy_vertices(leaves(x), :); dummy_vertices(partnerid, :)];
        end

        %regardless if it is stored or not, remove this mention in dummy_vertices
        elims = [elims; leaves(x)];

        for p=2:4
            if dummy_vertices(partnerid,p)==dummy_vertices(leaves(x),1)
                dummy_vertices(partnerid,p)=0;
            end
        end
    end

    for e=1:length(elims)
        dummy_vertices(elims(e),:)=[];
        elims=elims-1;
    end
end