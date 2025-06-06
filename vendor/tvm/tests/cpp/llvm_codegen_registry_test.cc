/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#ifdef TVM_LLVM_VERSION

#include <gmock/gmock.h>
#include <gtest/gtest.h>
#include <tvm/ffi/function.h>

#include <string>

#include "../../src/target/llvm/codegen_llvm.h"

#define CPU_TARGETS "arm", "cpu", "x86-64"
#define OPTIONAL_TARGETS "hexagon", "nvptx", "rocm"
#define ALL_TARGETS CPU_TARGETS, OPTIONAL_TARGETS

TEST(LLVMCodeGen, CodeGenFactoryPresent) {
  std::initializer_list<std::string> cpu_targets = {CPU_TARGETS};
  for (const std::string& s : cpu_targets) {
    auto pf = tvm::ffi::Function::GetGlobal("tvm.codegen.llvm.target_" + s);
    EXPECT_TRUE(pf.has_value());
  }

  std::initializer_list<std::string> optional_targets = {OPTIONAL_TARGETS};
  for (const std::string& s : optional_targets) {
    if (tvm::ffi::Function::GetGlobal("device_api." + s)) {
      auto pf = tvm::ffi::Function::GetGlobal("tvm.codegen.llvm.target_" + s);
      EXPECT_TRUE(pf.has_value());
    }
  }

  auto pf_bad = tvm::ffi::Function::GetGlobal("tvm.codegen.llvm.target_invalid-target");
  EXPECT_FALSE(pf_bad.has_value());
}

TEST(LLVMCodeGen, CodeGenFactoryWorks) {
  std::initializer_list<std::string> all_targets = {ALL_TARGETS};
  for (const std::string& s : all_targets) {
    if (auto pf = tvm::ffi::Function::GetGlobal("tvm.codegen.llvm.target_" + s)) {
      auto cg = (*pf)().cast<void*>();
      EXPECT_NE(cg, nullptr);
      delete static_cast<tvm::codegen::CodeGenLLVM*>(cg);
    }
  }
}

#endif  // TVM_LLVM_VERSION
