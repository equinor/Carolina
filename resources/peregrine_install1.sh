wget https://dakota.sandia.gov/sites/default/files/distributions/public/dakota-6.4-public.src.tar.gz ; tar -zxvf dakota-6.4-public.src.tar.gz ; cd dakota-6.4.0.src/ ; wget https://raw.githubusercontent.com/WISDEM/pyDAKOTA/master/resources/PeregrineBuild.cmake --no-check-certificate ; 

mkdir build; cd build

# 1. edit the path in ../PeregrineBuild.cmake line 35 to include your name: /home/YOURNAME/dakota
# 2. enter $ make -j 10 $  then $ make install$
# 3. set the following with your username (see instructions commented below in peregrine_install.sh):
# DAK_INSTALL=/home/jquick/dakota
# PATH=$DAK_INSTALL/bin:$DAK_INSTALL/test:$PATH
# LD_LIBRARY_PATH=$DAK_INSTALL/lib:$DAK_INSTALL/bin:$LD_LIBRARY_PATH
