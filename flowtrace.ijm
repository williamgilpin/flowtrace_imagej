/*
This macro allows time-resolved pathlines to be generated for a stack of images
When Batch mode is disabled, this script will run a lot faster whenImageJ is in 
the foreground of the GUI

Authors: William Gilpin, Vivek Prakash, and Manu Prakash
Stanford University, Stanford, CA

The "pairwise difference" option in this code takes advantage of the awesome "Kymograph" plugin
that is included in Fiji. For standalone ImageJ installations, this plugin is 
available from EMBL at http://www.embl.de/eamnet/html/kymograph.html and it should be 
attributed to J. Rietdorf, FMI Basel and A. Seitz, EMBL Heidelberg
*/

// set defaults
nmerge=10;
stride_len=1;

// For using linear weighting of later frames
diff_weight=false;

// For inverting bright field images
inv_flag=false;
clr_flag=false;

diff_flag=false;

stack_flag = false;

// Have user specify all of the relevant parameters
UseDialog = true;
if (UseDialog) {
    Dialog.create ("flowtrace");
    Dialog.addNumber ("Number of frames to merge:", nmerge);
    Dialog.addNumber ("Frames to skip (1 if none):", stride_len);

    Dialog.addCheckbox ("Fade the ends of trails", diff_weight);
    Dialog.addCheckbox ("Invert projection (for white background)", inv_flag);
    Dialog.addCheckbox ("Color Frames", clr_flag);
    Dialog.addCheckbox ("Pairwise Difference", diff_flag);
    Dialog.addCheckbox ("Subtract Median", diff_flag);
    Dialog.show ();

    nmerge = Dialog.getNumber ();
    stride_len = Dialog.getNumber ();
    diff_weight=Dialog.getCheckbox (); 
    inv_flag=Dialog.getCheckbox (); 
    clr_flag=Dialog.getCheckbox ();
    diff_flag=Dialog.getCheckbox ();
    med_flag=Dialog.getCheckbox ();
}

save_location = getDirectory("Select Directory to Save Images");

orig_stack=getTitle(); 
selectWindow(orig_stack);


setBatchMode(true);

// First build a linspace array of intermediate values
if (clr_flag) {
	bgcolor = newArray(90, 10, 250);
    fgcolor = newArray(255, 153, 0);

    incs = newArray(0,0,0);
    for (mm=0; mm<3; mm++) {
        bgcolor[mm] = bgcolor[mm]/255.0;
        fgcolor[mm] = fgcolor[mm]/255.0;
        incs[mm] = (fgcolor[mm]- bgcolor[mm])/nmerge;
    }
	
    rvals = Array.getSequence(nmerge);
    Array.fill(rvals, bgcolor[0]);
    for (qq=1; qq<rvals.length; qq++) {
        rvals[qq] = rvals[qq-1]+incs[0];
    }

    gvals = Array.getSequence(nmerge);
    Array.fill(gvals, bgcolor[1]);
    for (qq=1; qq<gvals.length; qq++) {
        gvals[qq] = gvals[qq-1]+incs[1];
    }

    bvals = Array.getSequence(nmerge);
    Array.fill(bvals, bgcolor[2]);
    for (qq=1; qq<bvals.length; qq++) {
        bvals[qq] = bvals[qq-1]+incs[2];
    }

    run("RGB Color");
}

iimax = nSlices - nmerge;
// The main loop through the images
for (ii=1; ii<iimax; ii++) {
    showProgress(ii, iimax); 

    if (ii==1) {
        if (stack_flag) {
            newImage("Streamline Stack", "RGB", getWidth, getHeight, 1); 
            new_stack = getTitle();
        }
    }

    selectWindow(orig_stack);
    nxt=ii+nmerge;
    range_name = ""+ii + "-" + nxt + "-" + stride_len;
    window_stride = "  slices="+ range_name;
    run("Make Substack...", window_stride);

    subname = "Substack ("+range_name+")";
    selectWindow(subname);

    if (diff_flag) {
        run("Stack Difference", "gap=1");
    }

    if (diff_weight) {
        for (jj=1; jj<nSlices; jj++) {
            wgt = (jj/nSlices);
            run("Multiply...", "value="+wgt);
            run("Next Slice [>]");
        }

    }

	if (med_flag) {
		run("Z Project...", "projection=[Median]");
		imageCalculator("Subtract stack", subname,"MED_"+subname);
		selectWindow("MED_"+subname);
    	close();
	}
	selectWindow(subname);

    if (clr_flag) {

        run("RGB Color");
        run("Split Channels");

        selectWindow(subname+" (red)");
        for (jj=0; jj<nmerge; jj++) {
            setSlice(jj+1);
            run("Multiply...", "value="+rvals[jj]+" slice");
        }
  
        selectWindow(subname+" (green)");
        for (jj=0; jj<nmerge; jj++) {
            setSlice(jj+1);
            run("Multiply...", "value="+gvals[jj]+" slice");
        }

        selectWindow(subname+" (blue)");
        for (jj=0; jj<nmerge; jj++) {
            setSlice(jj+1);
            run("Multiply...", "value="+bvals[jj]+" slice");
        }

        run("Merge Channels...", "c1=["+subname+" (red)] c2=["+subname+" (green)] c3=["+subname+" (blue)] create");    
        run("Flatten");
        rename(subname);

    }
    
    if (inv_flag) {
        run("Z Project...", "projection=[Min Intensity]");
    }
    else {
        run("Z Project...", "projection=[Max Intensity]");
    }

    rename("max_proj");
    max_proj=getTitle();

    selectWindow(max_proj);
    saveAs("Tiff", save_location + "streamlines_" + range_name + ".tif");
    max_proj=getTitle();

    if (stack_flag) {
        run("Concatenate...", "  title=[Streamline Stack] image1=[Streamline Stack] image2=[max_proj] image3=[-- None --]");
    }
    else {
        selectWindow(max_proj);
        close();
    }
   
    selectWindow(subname);
    close();

    
}

setBatchMode(false);

