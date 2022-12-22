#!/usr/bin/env python
# coding: utf-8

# In[6]:


import pandas as pd
from scipy.stats import gmean
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import inspect
from scipy.stats import gmean

plt.rcParams['figure.figsize'] = [30, 10]
plt.rcParams['figure.dpi'] = 400
plt.rc('font', family='serif', size='18')
import glob


# In[8]:
#
threads = [1, 2, 4, 8, 16, 32]
batchsizes = [2, 4, 6, 8, 12]


def run(name, backendr):
    data = list(open(name))
    idx = 1
    ret = []
    while idx < len(data):
        if 'backend' in data[idx] and idx+1 < len(data) and 'samples_per_second' in data[idx+1]:
            _, batch, prob, _, threads, backend = [x.strip().split(" ")[0] for x in data[idx].split(":")]
            sps = float(data[idx+1].split(" ")[-1].split(',')[0])
            ret.append({'backend':backendr, 'BatchSize':int(batch), 'size':int(prob), 'Threads':int(threads), 'sps':sps})
        idx+=1
    return ret

def merge(lists):
    out = []
    for l in lists:
        out += l
    return out
df = pd.DataFrame(merge([
    run(f, s+e) 
        for x in threads
            for (s, e) in [("native",""), ("moccuda","")]
                for f in glob.glob('../log/*{}_*omp{}{}.log'.format(s, x, e))
    ]))

def get(x):
    if len(x) > 0: return x[0]
    else: return float('nan')
    
def matrix(df):
    return [{
        'native':get(df.loc[(df['backend']=='native') & (df['Threads']==thread) & (df['BatchSize']==batch)]['sps'].values),
        'moccuda':get(df.loc[(df['backend']=='moccuda') & (df['Threads']==thread) & (df['BatchSize']==batch)]['sps'].values),
        'Threads':thread,'BatchSize':batch}
        for thread in threads
            for batch in batchsizes
            ]

print(df)
#print(np.array(df.groupby(['Threads'])))
#print(np.array(df.groupby(['Threads']).agg(gmean)))
#print(np.array(df.groupby(['Threads']).agg(gmean).index))
#print(np.array(df.groupby(['BatchSize']).agg(gmean).index[::-1]))
df = pd.DataFrame(matrix(df))
df = df.dropna()
df = df.set_index(['Threads', 'BatchSize'])
df


# In[9]:


df['speedup'] = df['moccuda'] / df['native']



# In[10]:


#print("Max speedup over dnnl:", max(df['speedup']))
#print("Min speedup over dnnl:", min(df['speedup']))
#print("Geomean speedup over dnnl:", gmean(df['speedup']))
#print("dnnl over vanilla geomean:", gmean(df['dnnl150']/df['native150']))
#print("Geomean speedup over expert:", gmean(df['moccuda_polter']/df['moccuda']))
#print("Speedup range over expert:", min(df['moccuda_polter']/df['moccuda']), max(df['moccuda_polter']/df['moccuda']))


# In[11]:


print(df)
speedup_heatmap = np.array([[df.loc[(thread, batch)]["speedup"] for thread in np.array(df.groupby(['Threads']).agg(gmean).index[::-1])] for batch in np.array(df.groupby(['BatchSize']).agg(gmean).index)]).transpose()


# In[12]:


ips = df.groupby(['Threads']).agg(gmean)
ips = ips.rename(columns={'native': 'Pytorch CPU', "moccuda":"MocCUDA+Polygeist"})


# In[13]:


fig = plt.figure(figsize=(12, 5))
axs = fig.subplots(1, 3, gridspec_kw={"width_ratios":[0.75, 0.05, 1.5]})
heatmap = axs[0].imshow(speedup_heatmap, aspect='auto', vmin=0)

axs[0].set_yticks(np.arange(len(np.array(df.groupby(['Threads']).agg(gmean).index)))[::-1])
axs[0].set_yticklabels(np.array(df.groupby(['Threads']).agg(gmean).index))
#axs[0].set_xticklabels(axs[0].get_xticklabels(), rotation = 35, horizontalalignment='right', verticalalignment='top')
axs[0].set_ylabel('Threads')
axs[0].set_xticks(np.arange(len(np.array(df.groupby(['BatchSize']).agg(gmean).index))))
axs[0].set_xticklabels(np.array(df.groupby(['BatchSize']).agg(gmean).index))
axs[0].set_xlabel('Batch Size')

lines = ips.plot(ax=axs[2], zorder=2, legend=False)
axs[2].set_xticks([1,4,8,12,18,24,32,42,48,64])
axs[2].set_ylabel('Throughput, samples/s')
axs[2].grid(zorder=1)
axs[2].set_ylim(0, None)

#fig.colorbar(heatmap, cax=axs[1])
pos = axs[1].get_position()
pos.x0 -= 0.03
pos.x1 -= 0.03
axs[1].set_position(pos)
axs[2].legend(loc='center', ncol=2, bbox_to_anchor=(0.25, 0.82, 0.5, 0.5), fontsize=14, frameon=False, fancybox=False)
plt.savefig("resnet50.pdf", bbox_inches="tight")


## In[4]:
#
#
#df.loc[(df['backend']=='native150') & (df['Threads']==1) & (df['BatchSize']==2)]['sps'].values
#
#
## In[6]:
#
#
#df.dropna().groupby(['Threads']).mean()
#
#
## In[7]:
#
#
#df.dropna().groupby(['BatchSize']).mean()
#
#
## In[8]:
#
#
#mocdat = np.array([[df.loc[(thread, batch)]["moccuda_polter"] for thread in np.array(df.groupby(['Threads']).agg(gmean).index)] for batch in np.array(df.groupby(['BatchSize']).agg(gmean).index[::-1])])
#onednn = np.array([[df.loc[(thread, batch)]["dnnl150"] for thread in np.array(df.groupby(['Threads']).agg(gmean).index)] for batch in np.array(df.groupby(['BatchSize']).agg(gmean).index[::-1])])
#
#
## In[9]:
#
#
#df.agg(gmean)
#
#
## In[117]:
#
#
#np.max(onednn)
#
#
## In[89]:
#
#
#fig = plt.figure(figsize=(12, 5))
#
#resultant = np.array([mocdat, onednn])
#min_val, max_val = np.amin(resultant), np.amax(resultant)
#axs = fig.subplots(1, 3, gridspec_kw={"width_ratios":[1, 1, 0.05]})
#
#colors = ["white", "red", "yellow", "black"]
#levels = [2, 4, 6, 8]
#mp = axs[0].imshow(mocdat, aspect='auto', vmin=min_val, vmax=max_val)
#mp2 = axs[0].contour(mocdat, aspect='auto', vmin=min_val, vmax=max_val,colors=colors, levels=levels)
#
#
#axs[1].imshow(onednn, aspect='auto', vmin=min_val, vmax=max_val)
#axs[1].contour(onednn, aspect='auto', vmin=min_val, vmax=max_val,colors=colors, levels=levels)
#
#
#for i, ax in enumerate(axs[:-1]):
#    ax.set_xticks(np.arange(len(np.array(df.groupby(['Threads']).agg(gmean).index))))
#    ax.set_xticklabels(np.array(df.groupby(['Threads']).agg(gmean).index))
#
#    if i == 0:
#        ax.set_yticks(np.arange(len(np.array(df.groupby(['BatchSize']).agg(gmean).index))))
#        ax.set_yticklabels(np.array(df.groupby(['BatchSize']).agg(gmean).index[::-1]))
#        ax.set_ylabel('Batch Size')
#
#    ax.set_title(["MoCCUDA_Polyg", "OneDNN"][i])
#
#    ax.set_xlabel('Thread Count')
#
## fig.subplots_adjust(right=0.85)
## cbar_ax = fig.add_axes([0.88, 0.15, 0.04, 0.7])
#cbar = fig.colorbar(mp, cax=axs[-1]) #axs[0], cax=cbar_ax)
#
#cbar.add_lines(mp2)
#
#fig.savefig('pytorch_conv2d_full.pdf', bbox_inches='tight')
#
#
## In[81]:
#
#
#fig = plt.figure(figsize=(5, 5))
#ax = fig.subplots(1, 1)
#ax = df.dropna().groupby(['Threads']).mean().plot(ax=ax)
#
#ax.set_ylabel('Images/second')
#ax.set_xlabel('Threads')
#
#lgd = ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.15),
#          fancybox=True, shadow=True, ncol=2)
#
#fig.savefig('pytorch_conv_threads.pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
#
#
## In[82]:
#
#
#fig = plt.figure(figsize=(5, 5))
#ax = fig.subplots(1, 1)
#ax = df.dropna().groupby(['BatchSize']).mean().plot(ax=ax)
#
#ax.set_ylabel('Images/second')
#ax.set_xlabel('BatchSize')
#
#lgd = ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.15),
#          fancybox=True, shadow=True, ncol=2)
#
#fig.savefig('pytorch_conv_batch.pdf', bbox_extra_artists=(lgd,), bbox_inches='tight')
#
#
## In[ ]:
#
#
#
#
