@echo off
echo Fixing finmem.mq5 ONNX files...
echo.

cd C:\Users\jimjj\Documents\my-trading-work
git pull origin claude/organize-library-review-011CUb1hnwSkqJehHZP3JdcD

echo Deleting old ONNX files...
del C:\Users\jimjj\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\OnnxRuntime.mqh
del C:\Users\jimjj\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\OnnxHandler.mqh

echo Copying fixed files...
copy OnnxRuntime.mqh C:\Users\jimjj\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\
copy OnnxHandler.mqh C:\Users\jimjj\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\

echo.
echo DONE! Now open MetaEditor and compile finmem.mq5
echo.
pause
