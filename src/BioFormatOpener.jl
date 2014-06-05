module BioFormatOpener

export bfOpen

	importall Base;
	using JavaCall;
	if ! JavaCall.isloaded()
		JavaCall.init(["-Djava.class.path=$(joinpath(Pkg.dir(), "View5D\\AllClasses"));$(joinpath(Pkg.dir(), "loci_tools.jar"))"]);
	end
	
	function bfOpen(nameFile)

		jChannelFiller		= @jimport "loci.formats.ChannelFiller";
		jChannelSeparator		= @jimport "loci.formats.ChannelSeparator";
		jIFormatReader		= @jimport "loci.formats.IFormatReader";
		jReaderWrapper		= @jimport "loci.formats.ReaderWrapper";
		jFormatTools			= @jimport "loci.formats.FormatTools";
		jDataTools			= @jimport "loci.common.DataTools";
	
		myChannelFiller     = jChannelFiller((),);
		myIFormatReader	  = convert(jIFormatReader,myChannelFiller);
		myChannelSeparator  = jChannelSeparator((jIFormatReader,), myIFormatReader);
		myReaderWrapper	  = convert(jReaderWrapper,myChannelSeparator);

		myFormatTools      = jFormatTools((),);

		jcall(myChannelSeparator, "setId", Void, (JString,),nameFile);
		nSeries = jcall(myReaderWrapper, "getSeriesCount", (jint), (),);
		print("Number of series ",nSeries,"\n");
		imageCELL = cell(nSeries,1);
		#imageseries = 0;
		for imageseries = 0:nSeries-1
			print(" Reading series ",imageseries,"\n");
			jcall(myChannelSeparator, "setSeries",Void,(jint,),imageseries);
			# Find out info on the image
			sz = [ convert(Int64,jcall(myChannelSeparator, "getSizeX",jint,(),)) , convert(Int64,jcall(myChannelSeparator, "getSizeY",jint,(),))];
			
			imsz = (sz[2],sz[1],convert(Int64,jcall(myChannelSeparator, "getSizeZ",jint,(),)),convert(Int64,jcall(myChannelSeparator, "getSizeC",jint,(),)),convert(Int64,jcall(myChannelSeparator, "getSizeT",jint,(),)));
			pixelType = jcall(myChannelSeparator, "getPixelType",jint,(),);
			bpp = jcall(jFormatTools, "getBytesPerPixel",jint,(jint,),pixelType);	
			fp  = jcall(jFormatTools, "isFloatingPoint",jboolean,(jint,),pixelType);	
			sgn = jcall(jFormatTools, "isSigned",jboolean,(jint,),pixelType);	
			little = jcall(myReaderWrapper, "isLittleEndian",jboolean,(),);
			numImages = jcall(myChannelSeparator, "getImageCount",jint,(),);

		    if numImages != prod(imsz[3:end])
				error("Assertion failed: number of planes in the image file not as expected!")
			end
		   
			if bpp==1
				if (sgn==0) 
					cls = Uint8;
				else
					cls = Int8;
				end
			elseif bpp==2
				if (sgn==0) 
					cls = Uint16;
				else
					cls = Int16;
				end
			elseif bpp==4
				if fp
					cls = Float32;
				else
					if (sgn==0) 
						cls = Uint32;
					else
						cls = Int32;
					end
				end
			elseif bpp==8
				if fp
					cls = Float64;
				else
					error("Unexpected number of bytes per pixel");
				end   
			else
				error("Unexpected number of bytes per pixel");
			end
			  
			#Allocate space and read all image planes
			image = zeros(cls,imsz);
		   
			#ii = zero(jint);
			for ii = 0:numImages-1
				#need at least a version of JavaCall of 09 mai 2014
				plane = jcall(myChannelSeparator, "openBytes",Array{jbyte,1},(jint,),ii);
				pos = jcall(myChannelSeparator, "getZCTCoords",Array{jint,1},(jint,),ii);
				#arr = jcall(jDataTools,"makeDataArray2D",JObject,(Array{jbyte,1},jint,jboolean,jboolean,jint),plane,bpp,fp,little,convert(Int32,sz[2]));
				if(little != 0)
					arr = plane;
				else
					arr = hton(plane);
				end
				arr = reinterpret(cls,arr);
				arr = reshape(arr,imsz[1],imsz[2]);
				image[:,:,1+pos[1],1+pos[2],1+pos[3]] = arr;
			end
			imageCELL[imageseries+1] = image;
		end
		return imageCELL;
	end




end # module
