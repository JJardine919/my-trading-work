/// \file
/// \brief unsupervised.cl
/// Library consist OpenCL kernels
/// \author <A HREF="https://www.mql5.com/en/users/dng"> DNG </A>
/// \copyright Copyright 2022, DNG
//---
//--- by default some GPU doesn't support doubles
//--- cl_khr_fp64 directive is used to enable work with doubles
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
//+------------------------------------------------------------------+
///\ingroup k-means K means clustering
/// Describes the process of dustance calculation for the class CKmeans (#CKmeans).
///\details Detailed description on <A HREF="https://www.mql5.com/ru/articles/10785#distance">the link.</A>
//+------------------------------------------------------------------+
__kernel void KmeansCulcDistance(__global double *data,///<[in] Inputs data matrix m*n, where m - number of patterns and n - size of vector to describe 1 pattern
                                 __global double *means,///<[in] Means tensor k*n, where k - number of clasters and n - size of vector to describe 1 pattern
                                 __global double *distance,///<[out] distance tensor m*k, where m - number of patterns and k - number of clasters
                                 int vector_size///< Size of vector
                                )
  {
   int m = get_global_id(0);
   int k = get_global_id(1);
   int total_k = get_global_size(1);
   double sum = 0.0;
   int shift_m = m * vector_size;
   int shift_k = k * vector_size;
   for(int i = 0; i < vector_size; i++)
      sum += pow(data[shift_m + i] - means[shift_k + i], 2);
   distance[m * total_k + k] = sum;
  }
//+------------------------------------------------------------------+
///\ingroup k-means K means clustering
/// Describes the process of output gradients calculation for the Neuron Base (#CNeuronBaseOCL).
///\details Detailed description on <A HREF="https://www.mql5.com/ru/articles/10785#clustering">the link.</A>
//+------------------------------------------------------------------+
__kernel void KmeansClustering(__global double *distance,///<[in] distance tensor m*k, where m - number of patterns and k - number of clasters
                               __global double *clusters,///<[out] Numbers of cluster tensor m-size
                               __global double *flags,///[out] Flags of changes
                               int total_k///< Number of clusters
                              )
  {
   int i = get_global_id(0);
   int shift = i * total_k;
   double value = distance[shift];
   int result = 0;
   for(int k = 1; k < total_k; k++)
     {
      if(value <= distance[shift + k])
         continue;
      value =  distance[shift + k];
      result = k;
     }
   flags[i] = (double)(clusters[i] != (double)result);
   clusters[i] = (double)result;
  }
//+------------------------------------------------------------------+
///\ingroup k-means K means clustering
/// Describes the process of updates means vectors
///\details Detailed description on <A HREF="https://www.mql5.com/ru/articles/10785#updates">the link.</A>
//+------------------------------------------------------------------+
__kernel void KmeansUpdating(__global double *data,///<[in] Inputs data matrix m*n, where m - number of patterns and n - size of vector to describe 1 pattern
                             __global double *clusters,///<[in] Numbers of cluster tensor m-size
                             __global double *means,///<[out] Means tensor k*n, where k - number of clasters and n - size of vector to describe 1 pattern
                             int total_m///< number of patterns
                            )
  {
   int i = get_global_id(0);
   int vector_size = get_global_size(0);
   int k = get_global_id(1);
   double sum = 0;
   int count = 0;
   for(int m = 0; m < total_m; m++)
     {
      if(clusters[m] != k)
         continue;
      sum += data[m * vector_size + i];
      count++;
     }
   if(count > 0)
      means[k * vector_size + i] = sum / count;
   
  }
//+------------------------------------------------------------------+
///\ingroup k-means K means clustering
/// Describes the process of loss function
///\details Detailed description on <A HREF="https://www.mql5.com/ru/articles/10785#loss">the link.</A>
//+------------------------------------------------------------------+
__kernel void KmeansLoss(__global double *data,///<[in] Inputs data matrix m*n, where m - number of patterns and n - size of vector to describe 1 pattern
                         __global double *clusters,///<[in] Numbers of cluster tensor m-size
                         __global double *means,///<[in] Means tensor k*n, where k - number of clasters and n - size of vector to describe 1 pattern
                         __global double *loss,///<[out] Loss tensor m-size
                         int vector_size///< Size of vector
                        )
  {
   int m = get_global_id(0);
   int c = clusters[m];
   int shift_c = c * vector_size;
   int shift_m = m * vector_size;
   double sum = 0;
   for(int i = 0; i < vector_size; i++)
      sum += pow(data[shift_m + i] - means[shift_c + i], 2);
   loss[m] = sum;
  }
//+------------------------------------------------------------------+
///\ingroup k-means K means clustering
/// Describes the calculation of probability  
///\details Detailed description on <A HREF="https://www.mql5.com/ru/articles/10785#statistic">the link.</A>
//+------------------------------------------------------------------+
__kernel void KmeansStatistic(__global double *clusters,///<[in] Numbers of cluster tensor m-size
                              __global double *target,///<[in] Targets tensor 3*m, where m - number of patterns
                              __global double *probability,///<[out] Probability tensor 3*k, where k - number of clasters
                              int total_m///< number of patterns
                             )
  {
   int c = get_global_id(0);
   int shift_c = c * 3;
   double buy = 0;
   double sell = 0;
   double skip = 0;
   for(int i = 0; i < total_m; i++)
     {
      if(clusters[i] != c)
         continue;
      int shift = i * 3;
      buy += target[shift];
      sell += target[shift + 1];
      skip += target[shift + 2];
     }
//---
   int total = buy + sell + skip;
   if(total < 10)
     {
      probability[shift_c] = 0;
      probability[shift_c + 1] = 0;
      probability[shift_c + 2] = 0;
     }
   else
     {
      probability[shift_c] = buy / total;
      probability[shift_c + 1] = sell / total;
      probability[shift_c + 2] = skip / total;
     }
  }
//+------------------------------------------------------------------+
