# Avoidant Traveling Networks

These codes accompany the paper "A traveling network model predicts emergent dynamics and search behavior from local remodeling in Physarum polycephalum: 
https://www.biorxiv.org/content/10.64898/2026.08.13.744445v1.article-info

There are three variants of the traveling network model, each with its associated main code: BaseCode.m, selfavoidance.m, and memoryavoid.m.

Following are which helper scripts are used in which codes. Place all the .m files in the same folder, and run either of the main codes. It should directly refer to the helper scripts without the user needing to do anything additional. Just make sure they are all placed in the same folder. 

1. BaseCode.m
  - StoreVert.m
  - StoreVertRet.m
  - storeFinalNetworkState.m 
2. selfavoidance.m
   - avoid.m
   - lineSegmentIntersect.m (this helper script/algorithm is obtained from: https://www.mathworks.com/matlabcentral/fileexchange/27205-fast-line-segment-intersection, by U. Murat Erdem)
3. memoryavoid.m
   - avoid.m
   - lineSegmentIntersect.m (see note above)
   - store_into_memory_time210818.m


