####################################################################################################
###                                                                                              ###
###   CopyChargesFromPSFtoPSF :: Looks up charges and creates a dictionary which enables         ###
###   transfer of charge information between single molecule representation .psf and entire      ###
###   system .psf files that enables a full charge picture of the entire system with VMD.        ###
###   of charge information between file formats with ease.                                      ###
###                                                                                              ###
###   Use in conjunction with top2psf which gonverts gromacs .itp file into .psf                 ###
###											         ###	
###   Often we need to ensure that we have a full .psf which covers every molecule in the        ###
###   system and that is what we use this program for - for extending the .psf charge to         ###
###   data to multiple molecule systems.                                                         ###
###   molecules.                                                                                 ###
###                                                                                              ###
###   Instructions:                                                                              ###
###   1. Create an individual .psf file from a .itp file using the well known top2psf perl tool  ###
###   2. Use VMD (autopsf) to generate the .psf file, probably without the charge info :-( from  ###
###      the .pdf or .gro file within the VMD environment (plugins).                             ###
###   3. Use this tool in conjunction with the files generated from 1. and 2. to build a list    ###
###      of all molecules in the system replete with charge data, leading to charges for         ### 
###      specified atoms in the original .itp file                                               ###
###   4. Copy and paste the output from 3. into the full system .psf file.                       ###     
###                                                                                              ###
###   Funding gratefully provided by Unilever plc and University of Southampton.                 ###
###                                                                                              ###
###   All code is "as is" and there is no implied warranty.                                      ###
###                                                                                              ###
###   Donovan (2011)  Flagged up for a rewrite....                                               ###
###                                                                                              ###
####################################################################################################

import cfg

mydict = {}  # Naughty global

def Get_Charges():
	FILE_frame = open(cfg.input_file, "r")
	line = FILE_frame.readline().strip()
	started_bool = False
	quit = False
	while (quit == False):   
		if (started_bool) and (line == ""):
			quit = True
			break
			#print "breaking..."
		if (line != ""):
			index = str(line.split()[0])
			#print index
			if (index) == "1":
				started_bool = True
		if (started_bool) and (line != ""):
			chem = str(line.split()[4])
			charge = str(line.split()[6])
			mydict[chem] = charge
		line = FILE_frame.readline().strip()	
	FILE_frame.close()
	print mydict

def Replace_Charges():
	new_segment = ""
	FILE_frame = open(cfg.output_file, "r")
	FILE_write = open(cfg.write_file, "w")  
	line = FILE_frame.readline().strip()
	started_bool = False
	quit = False
	while (quit == False):   
		if (started_bool) and (line == ""):
			quit = True
			break
			print "breaking..."
		if (line != ""):
			index = str(line.split()[0])
			if (index) == "1":
				started_bool = True
		if (started_bool) and (line != ""):
			chem = str(line.split()[4])
			charge = str(line.split()[6])
			A_curr = int(line.split()[0])
			B_curr = str(line.split()[1])
			C_curr = str(line.split()[2])
			D_curr = str(line.split()[3])
			E_curr = str(line.split()[4])
			F_curr = str(line.split()[5])
			G_curr = float(line.split()[6])
			H_curr = float(line.split()[7])
			I_curr = str(line.split()[8])
			if chem in mydict:
				G_curr = float(mydict[chem])
			### This line is horrid!	
			new_line = "   %5d" % A_curr + " " + B_curr + "   " + C_curr.ljust(5," ") + "" + D_curr.ljust(3," ") + "  " + E_curr.ljust(3," ") + "  " + F_curr + "   %+5f" % G_curr + "       %+5f" % H_curr + "         " + I_curr + "\n"
			FILE_write.write(new_line)
		line = FILE_frame.readline().strip()
			
		
	FILE_write.close()
	FILE_frame.close()

def main():

	Get_Charges()
	Replace_Charges()


if __name__ == "__main__":
	main()



