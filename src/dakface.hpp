// Copyright 2013 National Renewable Energy Laboratory (NREL)
//           2023 Equinor ASA
// 
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
// 
//        http://www.apache.org/licenses/LICENSE-2.0
// 
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
// 
// ++==++==++==++==++==++==++==++==++==++==
#ifndef _DAKFACE_H_
#define _DAKFACE_H_

#include "ParallelLibrary.hpp"

using namespace Dakota;

extern int all_but_actual_main(int argc, char* argv[], void *exc, bool throw_on_error);

#endif // _DAKFACE_H_
