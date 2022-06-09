import time
import argparse
import os,sys

import torch
import torch.nn as nn
import torch.optim as optim
import torch.utils.data as data

try:
  #import torchvision
  from torchvision.models import resnet50
except:
  # import from localfile
  from resnet import resnet50

from torch.backends import mkldnn
from torch.utils import mkldnn as mkldnn_utils

parser = argparse.ArgumentParser()
# test parameter options
parser.add_argument('--batch', type=int, default=32,
                    help="[option] batch size.")
parser.add_argument('--itr', type=int, default=20,
                    help="[option] max itaration.")
parser.add_argument('--lr', '--learning-rate', default=0.001, type=float,
                    metavar='LR', help='initial learning rate', dest='lr')
parser.add_argument('--momentum', default=0.9, type=float, metavar='M',
                    help='momentum')
parser.add_argument('--wd', '--weight-decay', default=0.0, type=float,
                    metavar='W', help='weight decay (default: 1e-4)',
                    dest='weight_decay')
# performance test option
type_list = ["gpu", "cpu_mkl", "cpu_nomkl", "cpu_mkltensor", "arm", "a64fx"]
parser.add_argument('--type', default="cpu_mkl", choices=type_list,
                    help='choose ' + ",".join(type_list))
# DEBUG option
parser.add_argument('--trace', action='store_true',
                    help='[option] get autograd.profiler')


def main():
  args = parser.parse_args()
  print(">> script option:",args)

  main_worker(args)


def main_worker(args):
  # set device, env-flag
  if args.type == "gpu":
    device = torch.device('cuda') # forCUDA
  if args.type in ["cpu_mkl", "cpu_mkltensor", "arm", "a64fx"]:
    device = torch.device('cpu')
  if args.type == "cpu_nomkl":
    mkldnn.enabled = False
    device = torch.device('cpu')

  ## load data
  batch_size = args.batch

  ## set net
  #net = torchvision.models.resnet50()
  net = resnet50()
  net = net.to(device)
  net.train()

  criterion = nn.CrossEntropyLoss()

  labels = torch.ones(batch_size,dtype=torch.long).to(device)
  inputs = torch.randn(batch_size, 3, 224, 224).to(device)

  if args.type == "cpu_mkltensor":
    mkldnn_utils.to_mkldnn(net)
    inputs = inputs.to_mkldnn()

  optimizer = optim.SGD(net.parameters(), lr=args.lr,
                        momentum=args.momentum,
                        weight_decay=args.weight_decay)

  torch.manual_seed(1)               # forPerformance
  if args.trace:
    with torch.autograd.profiler.profile(record_shapes=True) as prof: 
      laps = run_train(args, net, inputs, labels, criterion, optimizer)
    prof.export_chrome_trace("./trace.json")
    print(prof.key_averages().table(sort_by="self_cpu_time_total"))
  else:
    laps = run_train(args, net, inputs, labels, criterion, optimizer)

  output_statistics(laps)


def run_train(args, net, inputs, labels, criterion, optimizer):
  print("## Start Training")
  ## train
  laps = []
  running_loss = 0.0
  start = time.time()

  for i in range(args.itr):
    optimizer.zero_grad()

    outputs = net(inputs)
    if args.type == "cpu_mkltensor":
      loss = criterion(outputs.to_dense(), labels)
    else:
      loss = criterion(outputs, labels)
    loss.backward()
    optimizer.step()

    # print
    running_loss += loss.item()

    with torch.autograd.profiler.record_function("measure-print"): # label the block
      end = time.time()
      print('[%5d] loss: %.3f time: %0.3f s' %
        (i+1, running_loss, (end-start)))
      laps.append(end-start)
      start = time.time()

    running_loss = 0.0

  return laps


def output_statistics(laps):
  try:
    import pandas as pd
  except:
    print("please install pandas.")
  else:
    ds = pd.Series(laps[1:])
    print(ds.describe())


if __name__ == '__main__':
  main()

