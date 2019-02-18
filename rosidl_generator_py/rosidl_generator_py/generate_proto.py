import os
import glob

PRIMITIVE_TYPES = [
    'double',
    'float',
    'int32',
    'uint32',
    'uint64',
    'sint32',
    'sint64',
    'fixed32',
    'fixed64',
    'sfixed32',
    'sfixed64',
    'bool',
    'string',
    'bytes',

    'byte',
    'char',
    'int8',
    'int16',
    'int64',
    'uint8',
    'uint16',
    'float32',
    'float64',

]

subfolder = 'proto'

def msg2proto(msg_file_path, protos_dir,module_name,filename):

    var_names = []

    if not os.path.exists(protos_dir + '/{}'.format(module_name)):
        os.mkdir(protos_dir + '/{}'.format(module_name))

    proto_file_path = protos_dir + '/{}/{}/'.format(module_name,subfolder) + os.path.splitext(filename)[0] + '.proto'
    if not os.path.exists(os.path.dirname(proto_file_path)):
        os.makedirs(os.path.dirname(proto_file_path))

    # read msg
    with open(msg_file_path, 'r') as fp:
        lines = fp.readlines()

    out =[]
    for line in lines:
        line = line.strip()
        out.append(line)

    hascomment = False
    for line in out:
        if line.startswith('#'):
            hascomment = True

    package_name = module_name+".proto"

    type_name = os.path.splitext(os.path.basename(proto_file_path))[0]


    fields = []
    imports = []

    fields.append('message ' + type_name + ' {\n')

    idx = 1
    for line in out:
        if line.startswith('#') or len(line)==0:
            continue

        # with comment
        if line.find('#') != -1:
            kvc = line.split('#')
            kv = kvc[0]
            c  = kvc[1]
            kv = kv.split()
            k = kv[0]
            v = kv[1]
            c = ' //' + c
        else:
            kv = line.split()
            k = kv[0]
            v = kv[1]
            c = ''

        if k == 'float64':
            k = 'double'
        if k == 'byte':
            k = 'int32'
        if k == 'char':
            k = 'int32'
        if k == 'float32':
            k = "float"
        if k == 'int16':
            k = 'int32'
        if k == 'int8':
            k = 'int32'
        if k == 'uint16':
            k = 'uint32'
        if k == 'uint8':
            k = 'uint32'
        if k == 'int64':
            k = 'sint64'

        im_str = None
        if k.strip() == 'MultiArrayDimension[]':
            im_str = "import \"std_msgs/{}/MultiArrayDimension.proto\";\n".format(subfolder)
        elif k.strip() == 'MultiArrayLayout':
            im_str = "import \"std_msgs/{}/MultiArrayLayout.proto\";\n".format(subfolder)
        elif k.find('/') >0 :
            if k.find('[') >0 and k.find(']') >0:
                sub_k = k[:k.find('[')].strip()
                sub_k = sub_k[:sub_k.rindex('/')]+"/"+subfolder+ sub_k[sub_k.rindex('/'):]
                im_str = "import \""+sub_k+".proto\";\n"
            else:
                sub_k = k[:k.rindex('/')] + "/" + subfolder + k[k.rindex('/'):]
                im_str = "import \"" + sub_k.strip() + ".proto\";\n"

            k = k[:k.rindex('/')] + "/" + subfolder + k[k.rindex('/'):]
            k = k.replace('/','.')

        elif k not in PRIMITIVE_TYPES and k.find('string')<0:
            if k.find('[') > 0 and k.find(']') > 0:
                sk = k[:k.find('[')]
                if sk not in PRIMITIVE_TYPES:
                    im_str = "import \"" + module_name + "/"+subfolder+"/" + k[:k.find('[')].strip() + ".proto\";\n"
            else:
                im_str = "import \"" + module_name+"/"+subfolder+"/"+k + ".proto\";\n"

            # if im_str:
            #     print("="*20, im_str)
        if im_str and im_str not in imports:
            imports.append(im_str)

        if k.find('byte[') >=0 and k.find(']') >0:
            k = "bytes " + k[k.find(']')+1:]
        elif k.find('char[') >=0 and k.find(']') >0:
            k = "repeated int32 " + k[k.find(']')+1:]
        elif k.find('float32[') >=0 and k.find(']') >0:
            k = "repeated float " + k[k.find(']')+1:]
        elif k.find('float64[') >=0 and k.find(']') >0:
            k = "repeated double " + k[k.find(']')+1:]
        elif k.find('int16[') >= 0 and k.find(']') >0:
            k = "repeated int32 " + k[k.find(']') + 1:]
        elif k.find('int8[') >= 0 and k.find(']') >0:
            k = "repeated int32 " + k[k.find(']') + 1:]
        elif k.find('int64[') >= 0 and k.find(']') >0:
            k = "repeated sint64 " + k[k.find(']') + 1:]
        elif k.find('uint16[') >= 0 and k.find(']') >0:
            k = "repeated uint32 " + k[k.find(']') + 1:]
        elif k.find('uint8[') >= 0 and k.find(']') >0:
            k = "repeated uint32 " + k[k.find(']') + 1:]
        elif k.find('[') >0 and k.find(']') >0:
            if k.find("string") == 0:
                k = "repeated string"
            else:
                k = "repeated " + k[:k.find('[')]
        elif k.find('string') ==0:
            k = 'string'

        if v.find('=') >= 0:
            v = v[:v.find('=')]

        v_name = v.lower()
        if v_name not in var_names:
            var_names.append(v_name)
        else:
            v = v+"_proto"
            var_names.append(v_name+"_proto")

        fields.append('   ' + k + ' ' + v + ' = ' + str(idx) + ';' + c + '\n')
        idx += 1

    # write proto
    with open(proto_file_path, 'w') as fp:
        fp.write('syntax = "proto3";' + '\n')

        fp.write('package ' + package_name + ";\n\n")

        if hascomment:
            for line in out:
                if line.startswith('#'):
                    line = line.replace('#', '//')
                    fp.write(line + '\n')

        fields.append('}\n')

        for im in imports:
            fp.write(im)

        fp.write("\n")

        for fid in fields:
            fp.write(fid)

def get_protos_dir():
    protos_dir = '/tmp/protos'
    if 'ZORO_ROOT_DIR' in os.environ:
        protos_dir = os.path.join(os.environ['ZORO_ROOT_DIR'], 'protos')

    if not os.path.exists(protos_dir):
        os.makedirs(protos_dir)

    return protos_dir

def get_gen_py_dir():
    gen_py_dir = '/tmp/proto_gen_py'

    if 'ZORO_ROOT_DIR' in os.environ:
        gen_py_dir = os.path.join(os.environ['ZORO_ROOT_DIR'],'proto_gen_py')

    if not os.path.exists(gen_py_dir):
        os.makedirs(gen_py_dir)

    return gen_py_dir

def get_package_name(msg_file_path):
    dirname, filename = os.path.split(msg_file_path)
    dirname, _ = os.path.split(dirname)
    module_name = os.path.basename(dirname)

    return module_name,filename


def proto_gen_py(module_name):
    cmd = "/mnt/truenas/scratch/brewery/cellar/protobuf/3.6.1/bin/protoc -I " + get_protos_dir() \
           + " --python_out=" + get_gen_py_dir() + " " + get_protos_dir()+"/"+module_name+"/{}/*.proto".format(subfolder)

    os.system(cmd)

def cp_gen_py_to_proto(target_path,module_name):
    target_path = os.path.join(target_path,subfolder)
    if not os.path.exists(target_path):
        os.makedirs(target_path)

    cmd = "cp "+ os.path.join(get_gen_py_dir(),module_name,subfolder) +"/*.py" +" "+target_path

    os.system(cmd)