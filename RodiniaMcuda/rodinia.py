#!/usr/bin/env python
# coding: utf-8

# In[1]:


import os
import sys
import pandas as pd
pd.set_option('display.max_columns', 500)
import inspect
from scipy.stats import gmean

currentdir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parentdir = os.path.dirname(currentdir)
sys.path.insert(0, parentdir) 

def speedup(compiler, dropna=False):
    df2 = df.reset_index()
    dat = df2.loc[df2["compilername"] == compiler]
    dat = dat.drop(columns=["hostname", "compilername"])
    dat = dat.set_index('omp_thread_num')
    # dat = dat[1]
    dat = dat.loc[1].div(dat)
    if dropna:
        dat = dat.dropna()
    return dat


# In[2]:


from plot_timed_cuda import *


# In[3]:


plt.rcParams['figure.figsize'] = [30, 10]
plt.rcParams['figure.dpi'] = 400
plt.rc('font', family='serif', size='18')


# In[4]:

import glob
import os

list_of_results = glob.glob('/root/rodinia_results/rodinia_results_*')
latest_result = max(list_of_results, key=os.path.getctime)
print('plotting ' + latest_result)

openmp_results = latest_result + '/results/'
# openmp '../ubuntu_rodinia_results/2022-08-15T08:09:03,924029738+00:00/results/
cuda_results = latest_result + '/results/'
#cuda_results = '../ubuntu_rodinia_results/2022-08-17T18:06:10,889775445+00:00/results'

splice_sradv1 = False
if splice_sradv1:
    sradv1_results = '../ubuntu_rodinia_results/sradv1_final/results/'


# In[5]:


#timing_summaries_mincut = get_timing_summaries(glob.glob('./results/cuda/out/*.out') + glob.glob('./openmp2/*.out'), only_from=measurements_polygeist)
#newnw = get_timing_summaries(glob.glob('./newnw/*.out'), only_from=measurements_polygeist)

# timing_summaries_mincut = get_timing_summaries(glob.glob('./aws/results/cuda/out/*.out') + glob.glob('./aws/results/openmp/out/*.out'), only_from=measurements_polygeist)

timing_summaries_mincut = get_timing_summaries(glob.glob(cuda_results + '/cuda/out/*.out') + glob.glob(openmp_results + '/openmp/out/*.out'))
if splice_sradv1:
    sepsradv1_summaries = get_timing_summaries(glob.glob(sradv1_results + './cuda/out/*.out'))




# In[6]:


df = pd.DataFrame([{**d[0], **d[1]} for d in timing_summaries_mincut]) #.drop(columns=['hostname'])
df = df.groupby(['hostname', 'compilername', 'omp_thread_num']).median()
print(df)
#df = pd.DataFrame([{**d[0], **d[1]} for d in timing_summaries_mincut]).groupby(['hostname', 'compilername', 'omp_thread_num']).median()
#
#nw_df = pd.DataFrame([{**d[0], **d[1]} for d in newnw]).groupby(['hostname', 'compilername', 'omp_thread_num']).median()
# df = df.drop(columns=["nn euclid", "nn total", "gaussian "])
# df = df.drop(columns=["gaussian ", "nn total", "dwt2d c_CopySrcToComponents", "dwt2d fdwt53Kernel"])
#df = df.drop(columns=["nn total", "heartwall ", "lavaMD "])
#df = df.drop(columns=["particlefilter naive", "particlefilter float"])
df = df.drop(columns=["srad_v1 prepare", "nn euclid", "nn total", "heartwall ", "lavaMD ", "gaussian ", "backprop layerforward" ], errors='ignore')

#df = df.drop(columns=["srad_v1 total", "srad_v1 srad", "srad_v1 srad2", "srad_v1 compress", "srad_v1 reduce", "srad_v1 prepare"])

if splice_sradv1:
    df_sepsradv1 = pd.DataFrame([{**d[0], **d[1]} for d in sepsradv1_summaries]).groupby(['hostname', 'compilername', 'omp_thread_num']).median()
    df.update(df_sepsradv1, overwrite=True)

hostname = list(df.index)[0][0]
threads = list(df.index)[0][2]
#threads = 64
#hostname = " "
#threads = 32


# hostname = " memkf02.m.gsic.titech.ac.jp"
# threads = 24

# df.update(nw_df, overwrite=True)
df = df.rename(columns={"streamcluster kernel_compute_cost": "streamcluster", 
                        "srad_v2 srad_cuda_1":"srad_v2 kern1","srad_v2 srad_cuda_2":"srad_v2 kern2",
                        "nw _total":"nw total", "nw needle_cuda_shared_1":"nw kern1", "nw needle_cuda_shared_2":"nw kern2",
                        "dwt2d c_CopySrcToComponents":"dwt2d srcToComp", "dwt2d fdwt53Kernel": "dwt2d fdwt53", 'backprop layerforwardcu': 'backprop layerforward'
                       })
#print(df)

measurements_polygeist_kernels_with_barriers = [
        'b+tree findRangeK',
        'b+tree findK',
        'backprop adjust_weights', 'backprop layerforward',
        'dwt2d srcToComp', 'dwt2d fdwt53',
        'hotspot ',
        #'lavaMD ',
        'lud ',
        'nw kern1', 'nw kern2', 'nw total',
        'particlefilter float', 'particlefilter naive',
        'pathfinder ',
        'srad_v1 reduce',
        'srad_v1 total',
        'srad_v2 kern1', 'srad_v2 kern2',
        'srad_v2 total'
        ]
df = df.rename(columns={a:(a.strip()+"*") for a in measurements_polygeist_kernels_with_barriers})
df = df.reindex(sorted(df.columns), axis=1)


# In[7]:


df


# In[8]:


plt.figure(figsize=(10,4))
ser = (df.loc[(hostname, " openmp.polygeist-clang", threads)] /
  df.loc[(hostname, " polygeist.mincut.inner-serialize=1.raise-scf-to-affine.scal-rep=0", threads)]).dropna()
ser.name = "CUDA-OpenMP"
print(gmean(ser))
print(ser.sort_values())

    
ax = ser.plot.bar("", zorder=2)
ax.set_yscale("log")
yticks = [0.1, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64]
ax.set_yticks(yticks, map(str, yticks))
ax.grid(axis='y', zorder=1)
ax.grid(axis='y', zorder=1)
#ax.set_ylim(0, 8)

ax.set_ylabel('Speedup over OpenMP')
ax.axhline(1.0, color='gray', label = "OpenMP")

ax.set_xticklabels(ax.get_xticklabels(), rotation = 35, horizontalalignment='right', verticalalignment='top')
lgd = ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.3),
          fancybox=True, shadow=True, ncol=2)

plt.savefig('rodinia_omp.pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')

