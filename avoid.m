function [decision  out cmp]= avoid(vertices,freshleaf,growthpoint)
%DECISION = AVOID(VERTICES,FRESHLEAF,GROWTHPOINT) makes a decision on whether to create the new leaf or
%leaves base on whether it intersects with any branches in the network
%model.
%
%Variables:
%DECISION- will equal to 1 if no line intersection occurs (new leaf or
%   leaves allowed to be created). Will equal to 0 if line intersection
%   occurs).
%VERTICES- an array structured such as [identity partner1 partner2
%   partner3 xcoord ycoord retractionstate]. Size is some number of rows
%   and 7 columns (in the case that maximum degree is degree three)
%FRESHLEAF- an array containing the new leaf or leaves that are being created. Rows are the leaves, and columns are the x and y coordinates.
%   If growth, will be 1-by-2, being x and y coordinate. If branching, will be 2-by-2.
%GROWTHPOINT- a 1-by-2 array containing the x and y coordinates of the node
%   to branch or grow from.
%
%

num_digits_to_round = 10; %rounding the vertices array to make it recognize close to coincident lines
arb_large_val = 10^5; %arbitrary large value to see whether the intersection point is valid
num_error_thres = 1E-5; %numerical error threshold to check the difference between the intersection point and the growth point

decision = [];
[num_fresh,cc] = size(freshleaf);

for i=1:num_fresh %num_fresh == 2 means branching is attempted, with two new leaves %num_fresh == 1 means growth is attempted, with one new leaf. 
    intersect_occurred = 0;
    cmp=[];
    cmpcount = 0;
    node = freshleaf(i,:);
    xnode = node(1);
    ynode = node(2);
    at_beginning = 0;
    for v=1:size(vertices,1)
        for p=2:4
            if vertices(v,p)~=0
                for v2=1:size(vertices,1)
                    if vertices(v2,1)==vertices(v,p)
                        %plot ([vertices(v,5) vertices(v2,5)], [vertices(v,6) vertices(v2,6)],'k')
                        if ~(sum([vertices(v,5) vertices(v,6)] == [growthpoint(1) growthpoint(2)]) == 2 || sum([vertices(v2,5) vertices(v2,6)] == [growthpoint(1) growthpoint(2)]) == 2) 
                            cmpcount = cmpcount+1;
                            cmp(cmpcount,:)=[vertices(v,5) vertices(v,6) vertices(v2,5) vertices(v2,6)];
                        end
                    end
                end
            end
        end
    end
    
    %new change 5/26: if cmp ended up being empty, then rerun without that
    %constraint of vertices being equal to growthpoint
    if sum(size(cmp)) == 0
        at_beginning = 1;
        for v=1:size(vertices,1)
            for p=2:4
                if vertices(v,p)~=0
                    for v2=1:size(vertices,1)
                        if vertices(v2,1)==vertices(v,p)
                            %plot ([vertices(v,5) vertices(v2,5)], [vertices(v,6) vertices(v2,6)],'k')
                            cmpcount = cmpcount+1;
                            cmp(cmpcount,:)=[vertices(v,5) vertices(v,6) vertices(v2,5) vertices(v2,6)];
                        end
                    end
                end
            end
        end
    end
    
    out = lineSegmentIntersect(cmp,[growthpoint(1) growthpoint(2) xnode ynode]);
    %U. Murat Erdem (2020). Fast Line Segment Intersection(https://www.mathworks.com/matlabcentral/fileexchange/27205-fast-line-segment-intersection), MATLAB Central File Exchange. Retrieved September 16, 2020.
    intAdjacencyMatrix = out.intAdjacencyMatrix;
    intMatrixX = out.intMatrixX; %matrix of size N1 by N2 containing the X coordinate intersection point
    intMatrixY = out.intMatrixY; %matrix of size N1 by N2 containing the Y coordinate intersection point
    [r,c]=size(intMatrixX);
    for ii = 1:r
        if intAdjacencyMatrix(ii) && (intMatrixX(ii)~=0 || intMatrixY(ii)~=0)
            if intMatrixX(ii)>-arb_large_val && intMatrixX(ii)<arb_large_val && intMatrixY(ii)>-arb_large_val && intMatrixY(ii)<arb_large_val %Making sure intersection is a reasonable value rather than NaN
                if abs(intMatrixX(ii)-cmp(ii, 1))<num_error_thres && abs(intMatrixY(ii)-cmp(ii, 2))<num_error_thres
                    %If the intersection is right at
                    %the end of the line segment of the memory segment, don't count as
                    %intersect
                elseif abs(intMatrixX(ii)-cmp(ii, 3))<num_error_thres && abs(intMatrixY(ii)-cmp(ii, 4))<num_error_thres
                    %If the intersection is right at
                    %the other end of one of the memory segments, don't count as
                    %intersect
                elseif abs(intMatrixX(ii)-growthpoint(1))<num_error_thres && abs(intMatrixY(ii)-growthpoint(2))<num_error_thres
                    %If the intersection is right at
                    %the growth point, then don't count as intersect
                elseif abs(abs((growthpoint(1)-xnode)/(growthpoint(2)-ynode)) - abs((cmp(ii, 1)-cmp(ii, 3))/(cmp(ii, 2)-cmp(ii, 4)))) <= num_error_thres
                    %If parallel lines (calculated based on slope), then don't consider an intersection
                elseif at_beginning
                    if abs(intMatrixX(ii)-growthpoint(1))>num_error_thres || abs(intMatrixY(ii)-growthpoint(2))>num_error_thres %If the intersection is one of the ends of the new line segments, then don't count that
                        intersect_occurred = intersect_occurred + 1;
                        %intMatrixX(:,2)=zeros(1,r);
                        %intMatrixX(ii,2)=1;
                    end
                else
                    intersect_occurred = intersect_occurred + 1;
                    %fprintf('case4\n');
                    break;
                end
            end
        elseif out.coincAdjacencyMatrix == 1
            intersect_occurred = intersect_occurred + 1;
            break;
        end
    end
    if intersect_occurred == 0 %no line intersection occurs
        decision(i) = 1;
    else %line intersection occurs
        decision(i) = 0;
    end
end

