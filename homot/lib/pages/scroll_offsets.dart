// Static variables to hold the scroll positions of the different pages so that they're
// retained when you switch from page to page.  This is ugly, but seems to be the best
// solution Flutter supports because the pages get disposed when you navigate away from them.
double allStructureScrollOffset = 0.0;
double allEvalueScrollOffset = 0.0;
double selectedStructureScrollOffset = 0.0;
double selectedEvalueScrollOffset = 0.0;
